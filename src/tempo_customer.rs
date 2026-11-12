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

fn valid_identity(person: &str, tax_id: &str) -> bool {
    let person = person.trim();
    !person.is_empty()
        && person.chars().count() <= 80
        && !person.chars().any(char::is_control)
        && !tax_id.is_empty()
        && tax_id.len() <= 11
        && tax_id.bytes().all(|b| b.is_ascii_digit())
}

pub(crate) fn identity_ready() -> bool {
    valid_identity(
        &Config::get_option("tempo-person"),
        &Config::get_option("tempo-tax-id"),
    )
}

pub(crate) fn append_peer_identity(additions: &mut serde_json::Map<String, serde_json::Value>) {
    let person = Config::get_option("tempo-person");
    let tax_id = Config::get_option("tempo-tax-id");
    if valid_identity(&person, &tax_id) {
        additions.insert("tempo_full_name".into(), serde_json::json!(person));
        additions.insert("tempo_tax_id".into(), serde_json::json!(tax_id));
    }
}

#[cfg(test)]
mod tests {
    use super::valid_identity;

    #[test]
    fn requires_name_and_up_to_eleven_ascii_digits() {
        assert!(valid_identity("Muhammet Kapancı", "00123456789"));
        assert!(valid_identity("Muhammet", "1234567890"));
        for (name, tax_id) in [
            (" ", "123"),
            ("Ali", ""),
            ("Ali", "123456789012"),
            ("Ali", "12A34"),
        ] {
            assert!(!valid_identity(name, tax_id));
        }
    }
}
