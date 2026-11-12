use hbb_common::config::{self, Config};

pub(crate) fn enabled() -> bool {
    option_env!("TEMPO_CUSTOMER") == Some("1")
}

pub(crate) fn configure() {
    if !enabled() {
        return;
    }
    *config::APP_NAME.write().unwrap() = "TempoDestek".to_owned();
    let mut hard = config::HARD_SETTINGS.write().unwrap();
    hard.insert("conn-type".to_owned(), "incoming".to_owned());
    hard.insert("disable-installation".to_owned(), "Y".to_owned());
    hard.insert("disable-account".to_owned(), "Y".to_owned());
    drop(hard);
    let mut settings = config::OVERWRITE_SETTINGS.write().unwrap();
    for (key, value) in [
        ("custom-rendezvous-server", "uzak.tempobilisim.com"),
        ("api-server", "https://uzak.tempobilisim.com"),
        ("key", "haa8shM6MaOy6Qmi0WM1kr6qMkbR61t7aPskyGrfUcU="),
        ("approve-mode", "click"),
    ] {
        settings.insert(key.to_owned(), value.to_owned());
    }
}

pub(crate) fn decorate_sysinfo(value: &mut serde_json::Value) {
    if !enabled() {
        return;
    }
    let name = Config::get_option("preset-device-username");
    if !name.is_empty() {
        // Compare the effective name before deciding whether sysinfo needs re-uploading.
        value["username"] = serde_json::json!(name);
    }
}
