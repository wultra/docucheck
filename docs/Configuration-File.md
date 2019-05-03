# DocuCheck's Configuration File

This chapter of documentation describes the configuration file used by `DocuCheck` tool. You can check [Config.swift](../Sources/DocuCheck/Config/Config.swift) file which contains the latest structure representing the configuration. All naming in this document will follow that structure and its nested objects.

## Basic structure

The configuration file uses JSON format, with following elements at the top most object:

- `repositories` - dictionary, where the key is `repositoryIdentifier` and value is `Config.Repository` structure.
- `repositoryParameters` - optional dictionary, where the key is `repositoryIdentifier` and value is `Config.Parameters` structure
- `globalParameters` - optional `Config.GlobalParameters` structure, defining global parameters for `DocuCheck` tool, applied to all repositories.

**For example:**

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

The configuration above defines two source repositories (`powerauth-server` and `ssl-pinning-ios`), additional parameters (for `ssl-pinning-ios` repository) and global parameters, defining "docs" folder and "home" file names.

## `Config.Repository` structure

The `Config.Repository` defines the source of documentation for one particular repository. Following elements are available:

- `provider`, optional string, defines the sources provider. Following constants are available:
  - `github`, is default and applied if no string is specified. 
  - `gitlab`
- `remote`, required string, defines identifier or URL of remote git repository to acquire sources.
  - For `github` and `gitlab`, you have to specify identifier in form of `{organization}/{repository}`. For example `wultra/powerauth-server`
- `branch`, optional string, defines branch in git repository, to be cloned
- `tag`, optional string, defines tag in git repository, to be cloned
- `path`, optional string, defines directory to which the content of repository will be cloned. If no value is used, then the key from `"repositories"` dictionary is used. 
- `localFiles`, optional string, defines path to already cloned repository on a local file system. You can use this parameter to temporarily change source of documentation in case that you have that files already available. That's useful when you actively write on a documentation. 

**Addional notes:**

- If `tag` and `branch` are both specified, then the `tag` has a higher priority.
- If no `tag` and `branch` is specified, then `develop` branch is applied.
- It's not recommended to share configurations with `localFiles` parameter set. The full path to other location on filesystem is required and therefore such configuration usually will not work for another developer in your team. 

**Examples:**

```json
{
    "repositories": {
        "ssl-pinning-ios" : {
            "remote": "wultra/ssl-pinning-ios",
            "path": "pinning"
        },
        "powerauth-server": {
            "remote": "wultra/powerauth-server"
        }
    }
}
```
> Will collect documentation into `$OUT_DIR/ssl-pinning` and `$OUT_DIR/powerauth-server` directories

```json
{
    "repositories": {
        "ssl-pinning-ios" : {
            "remote": "wultra/ssl-pinning-ios",
            "tag": "1.0.0"
        },
        "powerauth-server": {
            "remote": "wultra/powerauth-server",
            "branch": "releases/0.21.x"
        }
    }
}
```
> Will checkout tag `1.0.0` for `ssl-pinning-ios` and branch `releases/0.21.x` for `wultra/powerauth-server`

## `Config.Parameters` structure

The `Config.Parameters` defines parameters for source repository, that are required for `DocuCheck` operations. Following elements are available:

- `docsFolder`, optional string, defines folder inside the cloned repository containing the documentation.
  - `docs` is default value
- `homeFile`, optional string, defines the name of file containing an initial page of the documentation
  - `Readme.md` is default value
- `auxiliaryDocuments`, optional array of strings, defines list of additional file names which are not pages with the documentation, but still must be processed as Markdown files.
  - `[ "_Sidebar.md", "_Footer.md" ]` is default value
- `ignoredFiles`, optional array of strings, defines list of ignored file names. Such files will not be copied to `$OUT_DIR`
  - `[ ".git", ".gitignore", ".DS_Store" ]` is default value
  - If value in list begins with asterisk `*`, then it's interpreted as wildcard. For example `*.bin` will exclude all files which names ends with `.bin` 
- `singleDocumentFile`, optional string, defines path (relative in source repository) to one markdown document.
  - If value is set, then it's expected that the whole application's documentation is composed from one single document.

**Addional notes:**

- It's not recommended to combine `homeFile` and `singleDocumentFile`. If both values are set, then `homeFile` is ignored.

**Effective values**

The default values for this structure can also be configured in `Config.GlobalParameters`. The effective value is then determined by following order: 

1. Per repository configuration has the highest priority
1. Global configuration
1. Default value is the fallback, if no other structure defines the value

This rule is not followed for `ignoredFiles` array. In this situation, the effective array is calculated as a combination from all levels.


**Examples:**

```json
{
    "repositories": {
        "ssl-pinning-ios" : {
            "remote": "wultra/ssl-pinning-ios",
        },
        "powerauth-server": {
            "remote": "wultra/powerauth-server",
            "branch": "releases/0.21.x"
        }
    },
    "repositoryParameters": {
        "ssl-pinning-ios": {
            "singleDocumentFile": "README.md"
        },
        "powerauth-server": {
            "ignoredFiles": [ "Schematics.psd", "*.bin" ]
        }
    }
}
```
> Tells `DocuCheck` that documentation of `ssl-pinning-ios` is composed from one single file and that `Schematics.psd` and all files with `bin` extension, should not be copied to final documentation.

### `Config.Paths` structure

This simple structure contains configuration for various paths required by the tool. Following elements are available:

- `outputPath`, optional string, if set, then changes path to `$OUT_DIR`
  - If value begins with `./` or `../`, then the path is interpreted as relative to path to the configuration file.
- `repositoriesPath`, optional string, if set, then changes path to `$REPO_DIR`
  - If value begins with `./` or `../`, then the path is interpreted as relative to path to the configuration file.
  
### `Config.GlobalParameters` structure

The `Config.GlobalParameters` defines parameters applied globally. You can for example change default parameters of source repositories. Following elements are available:

- `parameters`, optional [`Config.Parameters`](#configparameters-structure) object, modifies global values for all source repositories. 
- `paths`, optional [`Config.Paths`](#configpaths-structure) object, defining paths required by `DocuCheck`
- `markdownExtensions`, optional array of strings, defines file name extensions for Markdown document file types.
  - `[ "md", "markdown" ]` is default value
  - If you specify your own Markdown extensions, then the default extensions will be still recognized as a documents.
- `imageExtensions`, optional array of strings, defines file name extensions for image file types.
  - `[ "png", "jpg", "jpeg", "gif" ]` is default value
  - If you specify your own image extensions, then the default extensions will be still recognized as an images.
- `targetHomeFile`, optional string, defines the name of file containing an initial page of the documentation required by `jekyll`. All home files are automatically renamed to value configured in this property.
  - `index.md` is default value


**Examples:**

```json
{
    "repositories": {
        "powerauth-server": {
            "remote": "wultra/powerauth-server",
        }
    },
    "repositoryParameters": {
        "powerauth-server": {
            "ignoredFiles": [ "Schematics.psd", "*.bin" ]
        }
    },
    "globalParameters": {
        "parameters": {
            "homeFile": "Home.md",
            "ignoredFiles": [ "*.dat" ]
        },
        "imageExtensions": [ "jp2" ],
        "targetHomeFile": "index.html"
    }
}
```
> Changes default "home file" to `Home.md`, adds new globally ignored files with `.dat` extension, adds new image type `jp2` and changes target home file to `index.html`.

