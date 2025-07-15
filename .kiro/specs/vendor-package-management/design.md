# Vendor Package Management Design

## Overview

The vendor package management system will provide automated downloading and management of external JavaScript packages for the Elixir learning app. The system uses a configuration-driven approach where packages are defined in a JSON configuration file, and scripts handle the downloading and setup process.

## Architecture

The system consists of three main components:

1. **Configuration Management**: JSON-based configuration file defining vendor packages
2. **Download Scripts**: Shell scripts for fetching and organizing vendor packages  
3. **Integration Layer**: Integration with existing Phoenix asset pipeline and development workflow

## Components and Interfaces

### Configuration File (`assets/vendor.json`)

```json
{
  "packages": {
    "monaco-editor": {
      "version": "0.44.0",
      "url": "https://registry.npmjs.org/monaco-editor/-/monaco-editor-{version}.tgz",
      "files": [
        "package/min/vs/loader.js",
        "package/min/vs/editor/editor.main.js",
        "package/min/vs/editor/editor.main.css"
      ],
      "destination": "monaco-editor"
    },
    "topbar": {
      "version": "2.0.0", 
      "url": "https://raw.githubusercontent.com/buunguyen/topbar/v{version}/topbar.min.js",
      "destination": "topbar.js"
    }
  }
}
```

### Download Script (`scripts/download_vendor.sh`)

The script will:
- Read the vendor.json configuration
- Create the assets/vendor directory if it doesn't exist
- Download packages using curl/wget
- Extract and organize files according to configuration
- Verify successful downloads
- Provide clear error messages for failures

### Integration Points

#### Mix Tasks
- Custom Mix task `mix assets.vendor` for downloading packages
- Integration with existing `mix assets.setup` task

#### Development Workflow
- Automatic vendor package check in `dev_setup.sh`
- Integration with Phoenix asset watchers
- Proper asset pipeline inclusion

## Data Models

### Package Configuration Schema
```typescript
interface VendorConfig {
  packages: {
    [packageName: string]: {
      version: string;
      url: string;
      files?: string[];        // For extracting specific files from archives
      destination: string;     // Target path within assets/vendor/
      checksum?: string;       // Optional integrity verification
    }
  }
}
```

### Download Status Tracking
```elixir
defmodule VendorPackage do
  @type t :: %{
    name: String.t(),
    version: String.t(),
    status: :downloaded | :missing | :error,
    path: String.t(),
    last_updated: DateTime.t()
  }
end
```

## Error Handling

### Download Failures
- Network connectivity issues: Retry with exponential backoff
- Invalid URLs: Clear error message with configuration guidance
- File extraction errors: Detailed logging of extraction process
- Permission errors: Instructions for fixing directory permissions

### Configuration Errors
- Invalid JSON: JSON parsing error with line numbers
- Missing required fields: Validation with specific field requirements
- Invalid URLs: URL format validation before download attempts

### Recovery Mechanisms
- Automatic retry for transient network failures
- Fallback to cached versions when available
- Manual override options for problematic packages

## Testing Strategy

### Unit Tests
- Configuration parsing and validation
- URL generation and formatting
- File extraction and organization logic
- Error handling scenarios

### Integration Tests
- End-to-end package download process
- Integration with Phoenix asset pipeline
- Development workflow integration
- Cross-platform compatibility (macOS, Linux)

### Manual Testing
- Fresh development environment setup
- Package update scenarios
- Network failure simulation
- Configuration error handling

## Implementation Considerations

### Security
- URL validation to prevent malicious downloads
- Checksum verification for package integrity
- Sandboxed extraction process

### Performance
- Parallel downloads for multiple packages
- Caching of downloaded packages
- Incremental updates (only download changed packages)

### Maintainability
- Clear logging and error messages
- Modular script design for easy extension
- Documentation for adding new packages

### Cross-Platform Support
- Shell script compatibility across Unix-like systems
- Proper path handling for different operating systems
- Dependency management (curl, tar, unzip availability)