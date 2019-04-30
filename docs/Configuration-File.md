# DocuCheck's Configuration File

This chapter of documentation describes the configuration file used by DocuCheck tool. You can check [Config.swift](../Sources/DocuCheck/Config/Config.swift) file which contains the latest structure representing the configuration. All naming in this document will follow that structure and its nested objects.

## Basic structure

The configuration file uses JSON format, with following elements at the high level:

- `repositories` - dictionary, where the key is `repositoryIdentifier` and value is `Config.Repository` structure.
- `repositoryParameters` - optional dictionary, where the key is `repositoryIdentifier` and value is `Config.Parameters` structure
- `globalParameters` - optional `Config.GlobalParameters` structure, defining global parameters for DocuCheck tool, applied to all repositories.

For example:

```json
{
    "repositories": {
        "ssl-pinning-ios" : {
            "remote": "wultra/ssl-pinning-ios"
        },
        "powerauth-server": {
            "remote": "wultra/powerauth-server",
            "branch": "develop"
        }
    },
    "repositoryParameters": {
        "ssl-pinning-ios" : {
            "singleDocumentFile": "README.md"
        }
    },
    "globalParameters": {
        "parameters" : {
            "docPath": "docs",
            "homeFile": "Readme.md"
        }
    }
}
```

### `Config.Repository` structure

The `Config.Repository` defines the source of documentation for one particular repository.  

### `Config.Parameters` structure

### `Config.GlobalParameters` structure

