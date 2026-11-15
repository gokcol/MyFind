use serde::{Deserialize, Serialize};
use std::{
    collections::HashSet,
    io::{BufRead, BufReader},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
#[derive(Clone, Deserialize)]
pub struct Rule {
    pub field: String,
    pub op: String,
    pub value: String,
}
#[derive(Clone, Deserialize)]
pub struct Query {
    pub roots: Vec<String>,
    pub rules: Vec<Rule>,
    pub mode: String,
    pub any: bool,
    pub hidden: bool,
    pub packages: bool,
    pub case_sensitive: bool,
    pub max_depth: usize,
}
#[derive(Clone, Serialize, Deserialize)]
pub struct FileEntry {
    pub name: String,
    pub path: String,
    pub extension: String,
    pub kind: String,
    pub size: u64,
    pub modified: u64,
    pub created: Option<u64>,
    pub accessed: Option<u64>,
}
fn millis(t: SystemTime) -> u64 {
    t.duration_since(UNIX_EPOCH).unwrap_or_default().as_millis() as u64
}
pub fn validate(q: &Query) -> Result<(), String> {
    if q.roots.is_empty() {
        return Err("Choose at least one folder".into());
    }
    if !["hybrid", "fast", "thorough"].contains(&q.mode.as_str()) {
        return Err("Invalid search mode".into());
    }
    for r in &q.roots {
        if !Path::new(r).is_absolute() || !Path::new(r).is_dir() {
            return Err(format!("Folder is not available: {r}"));
        }
    }
    for r in &q.rules {
        if ![
            "name",
            "extension",
            "path",
            "kind",
            "size",
            "modified",
            "created",
            "accessed",
        ]
        .contains(&r.field.as_str())
        {
            return Err("Unsupported field".into());
        }
        if ![
            "contains",
            "not_contains",
            "equals",
            "starts",
            "ends",
            "regex",
            "glob",
            "greater",
            "less",
            "after",
            "before",
        ]
        .contains(&r.op.as_str())
        {
            return Err("Unsupported operator".into());
        }
        if r.op == "regex" {
            regex::Regex::new(&r.value).map_err(|e| e.to_string())?;
        }
        if ["size", "modified", "created", "accessed"].contains(&r.field.as_str()) {
            r.value
                .parse::<f64>()
                .map_err(|_| format!("{} requires a number", r.field))?;
        }
    }
    Ok(())
}
fn entry(p: &Path) -> Option<FileEntry> {
    let m = p.symlink_metadata().ok()?;
    let name = p.file_name()?.to_string_lossy().into_owned();
    Some(FileEntry {
        name,
        path: p.to_string_lossy().into_owned(),
        extension: p
            .extension()
            .unwrap_or_default()
            .to_string_lossy()
            .to_lowercase(),
        kind: if m.is_symlink() {
            "symlink"
        } else if m.is_dir() {
            "folder"
        } else {
            "file"
        }
        .into(),
        size: m.len(),
        modified: m.modified().map(millis).unwrap_or(0),
        created: m.created().ok().map(millis),
        accessed: m.accessed().ok().map(millis),
    })
}
fn matches(f: &FileEntry, r: &Rule, case: bool) -> bool {
    let n = match r.field.as_str() {
        "size" => Some(f.size),
        "modified" => Some(f.modified),
        "created" => f.created,
        "accessed" => f.accessed,
        _ => None,
    };
    if ["size", "modified", "created", "accessed"].contains(&r.field.as_str()) {
        return n
            .map(|n| {
                let v = r.value.parse::<f64>().unwrap_or(f64::NAN);
                match r.op.as_str() {
                    "greater" | "after" => (n as f64) > v,
                    "less" | "before" => (n as f64) < v,
                    "equals" => (n as f64) == v,
                    _ => false,
                }
            })
            .unwrap_or(false);
    }
    let s = match r.field.as_str() {
        "extension" => &f.extension,
        "path" => &f.path,
        "kind" => &f.kind,
        _ => &f.name,
    };
    let (s, v) = if case {
        (s.clone(), r.value.clone())
    } else {
        (s.to_lowercase(), r.value.to_lowercase())
    };
    match r.op.as_str() {
        "equals" => s == v,
        "not_contains" => !s.contains(&v),
        "starts" => s.starts_with(&v),
        "ends" => s.ends_with(&v),
        "regex" => regex::RegexBuilder::new(&r.value)
            .case_insensitive(!case)
            .build()
            .map(|re| re.is_match(&s))
            .unwrap_or(false),
        "glob" => {
            let pattern = format!(
                "^{}$",
                regex::escape(&v).replace("\\*", ".*").replace("\\?", ".")
            );
            regex::Regex::new(&pattern).unwrap().is_match(&s)
        }
        _ => s.contains(&v),
    }
}
fn excluded(p: &Path, q: &Query) -> bool {
    let rel = q
        .roots
        .iter()
        .filter_map(|r| p.strip_prefix(r).ok())
        .min_by_key(|r| r.components().count())
        .unwrap_or(p);
    if rel.components().count() > q.max_depth.max(1) {
        return true;
    }
    rel.components().enumerate().any(|(i, c)| {
        let n = c.as_os_str().to_string_lossy();
        (!q.hidden && n.starts_with('.'))
            || (!q.packages
                && i + 1 < rel.components().count()
                && [".app", ".bundle", ".framework"]
                    .iter()
                    .any(|ext| n.ends_with(ext)))
    })
}
// Index providers use documented OS query tools. Requests are passed as arguments or
// environment values; user input is never interpolated into shell source.
fn index(root: &str, cancel: &AtomicBool, mut visit: impl FnMut(PathBuf)) -> Result<(), String> {
    let mut command;
    if cfg!(target_os = "macos") {
        command = Command::new("/usr/bin/mdfind");
        command.args(["-0", "-onlyin", root, "kMDItemFSName == '*'"]);
    } else if cfg!(windows) {
        command = Command::new("powershell.exe");
        command.args(["-NoProfile","-NonInteractive","-Command",r#"$ErrorActionPreference='Stop'; [Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false); $c=New-Object System.Data.OleDb.OleDbConnection('Provider=Search.CollatorDSO;Extended Properties="Application=Windows"'); $c.Open(); $q=$c.CreateCommand(); $q.CommandText='SELECT System.ItemPathDisplay FROM SYSTEMINDEX'; $r=$q.ExecuteReader(); while($r.Read()){[Console]::Write($r.GetString(0)+[char]0)}; $c.Close()"#]);
    } else {
        return Err(
            "Native index integration is unavailable on this platform; use Thorough search.".into(),
        );
    }
    command.stdout(Stdio::piped()).stderr(Stdio::null());
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000);
    }
    let mut child = command.spawn().map_err(|e| e.to_string())?;
    let stdout = child.stdout.take().unwrap();
    let (tx, rx) = std::sync::mpsc::sync_channel(512);
    std::thread::spawn(move || {
        let mut reader = BufReader::new(stdout);
        loop {
            let mut bytes = Vec::new();
            match reader.read_until(0, &mut bytes) {
                Ok(0) | Err(_) => break,
                _ => {
                    bytes.pop();
                    if tx
                        .send(PathBuf::from(String::from_utf8_lossy(&bytes).into_owned()))
                        .is_err()
                    {
                        break;
                    }
                }
            }
        }
    });
    let start = Instant::now();
    let mut interrupted = false;
    loop {
        if cancel.load(Ordering::Relaxed) || start.elapsed() > Duration::from_secs(30) {
            interrupted = true;
            let _ = child.kill();
            break;
        }
        match rx.recv_timeout(Duration::from_millis(50)) {
            Ok(p) => {
                if p.starts_with(root) {
                    visit(p)
                }
            }
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {}
            Err(_) => break,
        }
    }
    drop(rx);
    let status = child.wait().map_err(|e| e.to_string())?;
    if interrupted {
        Err("Index query stopped or exceeded 30 seconds.".into())
    } else if !status.success() {
        Err("The operating system index is unavailable.".into())
    } else {
        Ok(())
    }
}
pub fn run(q: Query, cancel: Arc<AtomicBool>, mut emit: impl FnMut(serde_json::Value)) {
    let mut seen = HashSet::new();
    let mut batch = Vec::new();
    let mut scanned = 0usize;
    let mut skipped = 0usize;
    let mut count = 0usize;
    let start = Instant::now();
    let mut tick = Instant::now();
    let mut warnings = Vec::new();
    let mut visit = |p: PathBuf, source: &str| {
        scanned += 1;
        if !seen.contains(&p) && !excluded(&p, &q) {
            if let Some(f) = entry(&p) {
                let ok = q.rules.is_empty()
                    || if q.any {
                        q.rules.iter().any(|r| matches(&f, r, q.case_sensitive))
                    } else {
                        q.rules.iter().all(|r| matches(&f, r, q.case_sensitive))
                    };
                if ok && count < 50000 {
                    seen.insert(p);
                    batch.push(f);
                    count += 1;
                }
            }
        }
        if batch.len() >= 100 || tick.elapsed() > Duration::from_millis(150) {
            emit(
                serde_json::json!({"type":"batch","rows":batch,"scanned":scanned,"source":source}),
            );
            batch.clear();
            tick = Instant::now();
        }
    };
    if q.mode != "thorough" {
        for root in &q.roots {
            if cancel.load(Ordering::Relaxed) {
                break;
            }
            if let Err(e) = index(root, &cancel, |p| visit(p, "index")) {
                warnings.push(e);
            }
        }
    }
    if q.mode != "fast" {
        for root in &q.roots {
            for item in walkdir::WalkDir::new(root)
                .follow_links(false)
                .max_depth(q.max_depth.max(1))
                .into_iter()
                .filter_entry(|e| e.depth() == 0 || !excluded(e.path(), &q))
            {
                if cancel.load(Ordering::Relaxed) {
                    break;
                }
                match item {
                    Ok(e) => visit(e.path().into(), "filesystem"),
                    Err(_) => skipped += 1,
                }
            }
        }
    }
    drop(visit);
    emit(serde_json::json!({"type":"batch","rows":batch,"scanned":scanned,"source":"finished"}));
    emit(
        serde_json::json!({"type":"done","scanned":scanned,"skipped":skipped,"count":count,"cancelled":cancel.load(Ordering::Relaxed),"limited":count>=50000,"seconds":start.elapsed().as_secs_f64(),"warnings":warnings}),
    );
}
#[cfg(test)]
mod tests {
    use super::*;
    fn query(root: String) -> Query {
        Query {
            roots: vec![root],
            rules: vec![],
            mode: "thorough".into(),
            any: false,
            hidden: false,
            packages: false,
            case_sensitive: false,
            max_depth: 100,
        }
    }
    #[test]
    fn scan_filters_and_hides() {
        let d = tempfile::tempdir().unwrap();
        std::fs::write(d.path().join("Report.PDF"), "abc").unwrap();
        std::fs::write(d.path().join(".secret.pdf"), "").unwrap();
        let mut q = query(d.path().to_string_lossy().into());
        q.rules.push(Rule {
            field: "extension".into(),
            op: "equals".into(),
            value: "pdf".into(),
        });
        let mut rows = vec![];
        run(q, Arc::new(AtomicBool::new(false)), |v| {
            if v["type"] == "batch" {
                rows.extend(v["rows"].as_array().unwrap().clone());
            }
        });
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["name"], "Report.PDF");
    }
    #[test]
    fn invalid_regex_rejected() {
        let mut q = query(std::env::temp_dir().to_string_lossy().into());
        q.rules.push(Rule {
            field: "name".into(),
            op: "regex".into(),
            value: "[".into(),
        });
        assert!(validate(&q).is_err());
    }
    #[test]
    fn cancellation_finishes() {
        let q = query(std::env::temp_dir().to_string_lossy().into());
        let mut done = false;
        run(q, Arc::new(AtomicBool::new(true)), |v| {
            if v["type"] == "done" {
                done = v["cancelled"].as_bool().unwrap();
            }
        });
        assert!(done);
    }
}
