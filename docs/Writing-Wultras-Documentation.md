# Writing Wultra's documentation

This document describes how to create a proper documentation for Wultra's application.

## Structure of documentation
 
- Put `docs` folder to the root of repository. The folder should contain all documentation visible at our developers portal

- Put `README.md` file to the root of repository
  - This file is automatically visible when the repository is opened at GitHub webpage
  - The file should contain only brief information about the application and should redirect the user to the `docs/Readme.md`.
  
- `docs/Readme.md` should be a "home" file 

- Create `docs/_Sidebar.md` file with sidebar navigation.

- Use only limited set of characters for file names used in the documentation.
  - It's recommended to use only characters, numbers, hyphen, dot
  - Never use brackets and space character for file names.

- Use camel case names or separate words with hyphen character

**Examples:**

- `Some-Long-File-Name.md`
- `SomeLongFileName.md`
- `Features-(Experimental).md` - should not be used as file name

## Recommended workflow

1. Clone [`wultra/wultra-developers`](https://github.com/wultra/wultra-developers)
   - Run `./update-develop.sh` to get the latest changes for the documentation in the development.
   - Let's say, you have cloned that repo into `/Users/johndoe/Dev/docs/wultra-developers`.

1. Clone or pull latest changes for repository you're going to update.
   - Let's say, you're going to update documentation for [`wultra/ssl-pinning-ios`](https://github.com/wultra/ssl-pinning-ios)
   - Let's say, you have cloned that repo into `/Users/johndoe/Dev/libs/ssl-pinning-ios`.
   - Create a new branch from current `develop` branch. For example `features/documentation-update`.
   
1. Add local path to DocuCheck's configuration:
   - Edit `/Users/johndoe/Dev/docs/wultra-developers/releases/develop.json`
   - Put `"localFiles"` key into the configuration. For example:
     ```json
     {
         "repositories": {
             "ssl-pinning-ios" : {
                 "remote": "wultra/ssl-pinning-ios",
                 "localFiles": "/Users/johndoe/Dev/libs/ssl-pinning-ios"
             },
         }
     }
     ```

1. Run `./update-develop.sh --fast` every time you change documentation for `ssl-pinning-ios`

1. Optional but recommended, run `./run-local-server.sh` in another console
   - Test your changes live at `http://127.0.0.1:4000/docs/develop/` ([open link](http://127.0.0.1:4000/docs/develop/))
   - You can keep the local server up and running. It will reflect your changes automatically. Just wait a couple of seconds and then reload the page.

1. After you're done with your changes, then:
   - Revert the configuration you modified in step #3 
   - Push updated documentation into that `features/documentation-update` branch
   - Make a pull request with your changed documentation
   - Wait for a review...
  
1. If the change is approved and merged to `wultra/ssl-pinning-ios`'s `develop`, then run `./update-develop.sh` for the last time.

1. If everything's OK (no DocuCheck WARNING is reported), then you can commit and push the change to `wultra/wultra-developers`'s `master` branch to make it live on the portal.


## Markdown links

This chapter describes how to create a proper links in our documentation.

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

The reason why this will work is that `DocuCheck` collects all documentation files into one folder (`$OUT_DIR`) and therefore final links are just relative paths.

### Keep link as it is

If you want to keep the link as it is, then add `#docucheck-keep-link` anchor. This is useful in situations when you want to really redirect user to a GitHub webpage:

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

Our preprocessor cannot automaticaly detect emails in the text, just like GitHub does and therefore you have to make a full link with email (e.g. link with `mailto:` scheme). For example:

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

If you do not specify `TOC` section, then `DocuCheck` will generate `_Sidebar.md` from document's headers, but that may lead to less quality navigation. The good examples are our libraries for dynamic SSL pinning [for iOS](https://github.com/wultra/ssl-pinning-ios) and [for Android](https://github.com/wultra/ssl-pinning-android). Both have the whole documentation in a single page, but unlike the first one, the Android library has auto-generated TOC.