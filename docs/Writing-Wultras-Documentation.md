# Writing Wultra's documentation

This document describes how to create proper documentation for Wultra's application.

## Structure of documentation
 
- Put `docs` folder to the root of repository. The folder should contain all documentation visible at our developers portal

- Put `README.md` file to the root of repository
  - This file is automatically visible when the repository is opened at GitHub webpage
  - The file should contain only brief information about the application and should redirect the user to the `docs/Readme.md`.
  
- `docs/Readme.md` should be a "home" file 

- Use only limited set of characters for file names used in the documentation.
  - It's recommended to use only characters, numbers, hyphen, dot
  - Never use brackets and space character for file names.

- Use camel case names or separate words with hyphen character

**Examples:**

- `Some-Long-File-Name.md`
- `SomeLongFileName.md`
- `Features-(Experimental).md` - should not be used as file name


## Markdown links

### Local link

Local links points to the file in the same repository. Use relative path to the file. Examples:
```md
- [Additional Information](Additional-Info.md)
- ![Flowchart 3](images/Flowchart-3.png)
- Go to [Home page](../Readme.md)
```

### Link to another repository

You have basically two options for making links to another repository:

1. If you want to make a link to the home page of another repository, then use URL to repository at GitHub. For example:
   - `[PowerAuth mobile SDK](https://github.com/wultra/powerauth-mobile-sdk)`
   - Such link will be traslated to `[PowerAuth mobile SDK](../powerauth-mobile-sdk/Readme.md)`
  
2. If you want to make a link to document in another repository, then use full versioned link to document, available at `develop` branch. For example:
   - `[iOS documentation](https://github.com/wultra/powerauth-mobile-sdk/blob/develop/docs/PowerAuth-SDK-for-iOS.md)` 
   - Will be translated to a sequence like `[iOS documentation](../powerauth-mobile-sdk/PowerAuth-SDK-for-iOS.md)`

The reason why this will work is that docucheck collects all documentation files into one folder (`$OUT_DIR`) and therefore final links are just relative paths.

### Keep link as it is

If you want to keep the link as it is, then add `#docucheck-keep-link` anchor. This is useful in following situations when you want to really redirect user to a GitHub webpage:

- `[Show file at GitHub](https://github.com/wultra/powerauth-mobile-sdk/blob/develop/docs/PowerAuth-SDK-for-iOS.md#docucheck-keep-link)`
- The link above will be kept as it is, `DocuCheck` just removes that additional anchor.


### Anchor

Anchor name is typically calculated from the header. Following rules are used to calculate name of anchor:

- All characters are lowercased
- All characters, except alphanumeric, are replaced with hyphen.
- Two or more hyphes are converted into only one
- Dots and backquotes are ignored.

Anchors can be combined with all link types above.

Examples:

| Header text                 | Anchor |
|-----------------------------|--------|
| Hello world                 | `#hello-world` |
| `code.9` in title.          | `#code9-in-title` |
| Chapter 4.2                 | `#chapter-42` |
| Carthage (experimental)     | `#carthage-experimental` |

### Email

Our preprocessor cannot automaticaly detect emails in the text, just like GitHub does and therefore you have make full link with email (e.g. link with `mailto:` protocol). For example:

```md
## Contact

If you need any assistance, do not hesitate to drop us 
a line at [hello@wultra.com](mailto:hello@wultra.com) or 
our official [gitter.im/wultra](https://gitter.im/wultra) channel.
```

### Link to local source file

In case that you want to make link to source file in the same repository, use relative path, which escapes `docs` folder. `DocuCheck` translates such links into fully versioned link, pointing to GitHub webpage. For example:

- Link `[main.swift](../Sources/DocuCheck/main.swift)`
- Will be translated to `https://github.com/wultra/docucheck/blob/develop/Sources/DocuCheck/main.swift`


## Single page documentation

If documentation is composed from one single file, then you should:

- Put "Table of Contents" at the beginning of document
- Mark "Table of Contents" with a meta-data marker "TOC". See [Meta-data](Basic-Principles.md#generate-toc) in Basic Principles.

If you not specify `TOC` section, then `DocuCheck` will generate `_Sidebar.md` from document's headers, but that may lead to lesser quality navigation. 

