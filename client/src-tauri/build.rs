fn main() {
    let env_path = std::env::var("TAURI_ENV_FILE").unwrap_or_else(|_| "../../server/.env".into());
    println!("cargo:rerun-if-env-changed=TAURI_ENV_FILE");
    println!("cargo:rerun-if-env-changed=PHOENIX_SERVER_DNS");
    println!("cargo:rerun-if-changed={env_path}");

    let env_file = std::fs::read_to_string(env_path).unwrap_or_default();
    let value_for = |name: &str| {
        env_file
            .lines()
            .map(str::trim)
            .find_map(|line| line.strip_prefix(name))
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| value.trim_matches(['\"', '\'']).to_owned())
    };

    let configured_dns = std::env::var("PHOENIX_SERVER_DNS")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .or_else(|| value_for("PHOENIX_SERVER_DNS="))
        .or_else(|| {
            value_for("GOOGLE_REDIRECT_URI=").and_then(|redirect_uri| {
                let scheme_end = redirect_uri.find("://")? + 3;
                let path_start = redirect_uri[scheme_end..]
                    .find('/')
                    .map(|index| scheme_end + index)?;
                Some(redirect_uri[..path_start].to_owned())
            })
        });

    if let Some(dns) = configured_dns {
        println!("cargo:rustc-env=PHOENIX_SERVER_DNS={dns}");
    }

    tauri_build::build()
}
