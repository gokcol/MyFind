#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
mod search;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use tauri::{Emitter, Manager};
#[derive(Default)]
struct Jobs(Mutex<Option<Arc<AtomicBool>>>);
#[tauri::command]
fn home() -> String {
    std::env::var(if cfg!(windows) { "USERPROFILE" } else { "HOME" }).unwrap_or_default()
}
#[tauri::command]
fn cancel(jobs: tauri::State<Jobs>) {
    if let Some(c) = jobs.0.lock().unwrap().as_ref() {
        c.store(true, Ordering::Relaxed);
    }
}
#[tauri::command]
fn search(
    app: tauri::AppHandle,
    jobs: tauri::State<Jobs>,
    query: search::Query,
    id: String,
) -> Result<(), String> {
    search::validate(&query)?;
    let flag = Arc::new(AtomicBool::new(false));
    if let Some(old) = jobs.0.lock().unwrap().replace(flag.clone()) {
        old.store(true, Ordering::Relaxed);
    }
    std::thread::spawn(move || {
        search::run(query, flag, |event| {
            let _ = app.emit("search-update", serde_json::json!({"id":id,"event":event}));
        });
    });
    Ok(())
}
#[tauri::command]
fn export_csv(path: String, rows: Vec<search::FileEntry>) -> Result<(), String> {
    let quote = |s: &str| {
        format!(
            "\"{}\"",
            if s.starts_with(['=', '+', '-', '@', '\t', '\r']) {
                format!("'{}", s.replace('"', "\"\""))
            } else {
                s.replace('"', "\"\"")
            }
        )
    };
    let mut out = String::from("Name,Path,Size bytes,Modified epoch ms,Created epoch ms\n");
    for r in rows {
        out.push_str(&format!(
            "{},{},{},{},{}\n",
            quote(&r.name),
            quote(&r.path),
            r.size,
            r.modified,
            r.created.unwrap_or(0)
        ));
    }
    std::fs::write(path, out).map_err(|e| e.to_string())
}
fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .manage(Jobs::default())
        .invoke_handler(tauri::generate_handler![home, search, cancel, export_csv])
        .on_window_event(|w, e| {
            if matches!(e, tauri::WindowEvent::Destroyed) {
                if let Some(c) = w.state::<Jobs>().0.lock().unwrap().as_ref() {
                    c.store(true, Ordering::Relaxed);
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("Unable to start Calico Sleuth");
}
