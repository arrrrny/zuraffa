use std::env;
use zed_extension_api::{
    self as zed, Command, ContextServerId, DownloadedFileType, Project, Result,
};

const VERSION: &str = "3.0.2";

struct ZuraffaExtension;

impl zed::Extension for ZuraffaExtension {
    fn new() -> Self {
        Self
    }

    fn context_server_command(
        &mut self,
        _context_server_id: &ContextServerId,
        _project: &Project,
    ) -> Result<Command> {
        let binary_path = Self::download_or_get_binary()?;

        Ok(Command {
            command: binary_path,
            args: vec![],
            env: vec![],
        })
    }
}

impl ZuraffaExtension {
    fn download_or_get_binary() -> Result<String> {
        let (os, arch) = zed::current_platform();

        let (os_name, arch_name) = match (os, arch) {
            (zed::Os::Mac, zed::Architecture::Aarch64) => ("macos", "arm64"),
            (zed::Os::Mac, zed::Architecture::X8664) => ("macos", "x64"),
            (zed::Os::Linux, zed::Architecture::X8664) => ("linux", "x64"),
            (zed::Os::Windows, zed::Architecture::X8664) => ("windows", "x64"),
            _ => return Err(format!("Unsupported platform: {:?} {:?}", os, arch).into()),
        };

        let binary_name = if os == zed::Os::Windows {
            format!("zuraffa_mcp_server-{}-{}.exe", os_name, arch_name)
        } else {
            format!("zuraffa_mcp_server-{}-{}", os_name, arch_name)
        };

        let binary_path = env::current_dir()
            .map_err(|e| e.to_string())?
            .join(&binary_name);

        if !binary_path.exists() {
            let url = format!(
                "https://github.com/arrrrny/zuraffa/releases/download/v{}/{}",
                VERSION, binary_name
            );
            zed::download_file(&url, &binary_name, DownloadedFileType::Uncompressed)?;
        }

        let binary_path_str = binary_path.to_string_lossy().to_string();
        zed::make_file_executable(&binary_path_str)?;

        Ok(binary_path_str)
    }
}

zed::register_extension!(ZuraffaExtension);
