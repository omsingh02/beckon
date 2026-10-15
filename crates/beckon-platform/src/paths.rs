//! Where the server keeps its identity key and paired-device list.

use std::io;
use std::path::{Path, PathBuf};

/// Default per-user config directory:
///
/// * Windows: `%APPDATA%\Beckon`
/// * macOS:   `~/Library/Application Support/Beckon`
/// * Linux and other Unix: `$XDG_CONFIG_HOME/beckon` (default `~/.config/beckon`)
///
/// Falls back to `./beckon-data` only when the OS reports no home directory
/// at all (a bare service account), so the server still starts.
pub fn default_config_dir() -> PathBuf {
    resolve_config_dir(dirs::config_dir())
}

fn resolve_config_dir(config_dir: Option<PathBuf>) -> PathBuf {
    let Some(base) = config_dir else {
        return PathBuf::from("./beckon-data");
    };
    base.join(app_dir_name())
}

/// Creates `dir` and any missing parents. Directories created by this call are
/// private to the current user on Unix (mode 0700); one that already exists is
/// left exactly as it is, since it may be a shared location the user chose.
pub fn ensure_private_dir(dir: &Path) -> io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::DirBuilderExt;
        std::fs::DirBuilder::new()
            .recursive(true)
            .mode(0o700)
            .create(dir)
    }
    #[cfg(not(unix))]
    {
        std::fs::create_dir_all(dir)
    }
}

fn app_dir_name() -> &'static str {
    if cfg!(any(windows, target_os = "macos")) {
        "Beckon"
    } else {
        "beckon"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dir_is_namespaced_under_the_platform_config_dir() {
        let dir = resolve_config_dir(Some(PathBuf::from("/cfg")));
        assert!(dir.starts_with("/cfg"));
        assert_eq!(dir.file_name().unwrap(), app_dir_name());
        if cfg!(any(windows, target_os = "macos")) {
            assert_eq!(app_dir_name(), "Beckon");
        } else {
            assert_eq!(app_dir_name(), "beckon");
        }
    }

    #[test]
    fn no_home_directory_falls_back_to_a_local_folder() {
        assert_eq!(resolve_config_dir(None), PathBuf::from("./beckon-data"));
    }

    #[test]
    fn default_dir_resolves_on_this_machine() {
        let dir = default_config_dir();
        assert!(dir.ends_with(app_dir_name()) || dir == Path::new("./beckon-data"));
    }

    fn scratch(tag: &str) -> PathBuf {
        std::env::temp_dir().join(format!("beckon_paths_{tag}_{}", std::process::id()))
    }

    #[test]
    fn ensure_private_dir_creates_nested_directories_and_is_idempotent() {
        let root = scratch("nested");
        let _ = std::fs::remove_dir_all(&root);
        let leaf = root.join("a").join("b");
        ensure_private_dir(&leaf).unwrap();
        assert!(leaf.is_dir());
        ensure_private_dir(&leaf).unwrap();
        std::fs::remove_dir_all(&root).unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn new_directories_are_private_but_existing_ones_are_untouched() {
        use std::os::unix::fs::PermissionsExt;
        let root = scratch("perms");
        let _ = std::fs::remove_dir_all(&root);
        let created = root.join("beckon");
        ensure_private_dir(&created).unwrap();
        let mode = |p: &Path| std::fs::metadata(p).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode(&created), 0o700);

        // A pre-existing, deliberately shared directory keeps its permissions.
        let shared = root.join("shared");
        std::fs::create_dir_all(&shared).unwrap();
        std::fs::set_permissions(&shared, std::fs::Permissions::from_mode(0o755)).unwrap();
        ensure_private_dir(&shared).unwrap();
        assert_eq!(mode(&shared), 0o755);
        std::fs::remove_dir_all(&root).unwrap();
    }
}
