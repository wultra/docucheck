# Basic Principles

## General Terminology

We're using the following terminology in this documentation:

- **"Application"** is one particular product which supposes to be documented. For example "PowerAuth Server."
- **"Source repository"** is a git repository containing source codes and documentation written in Markdown, for one particular application. For example `https://github.com/wultra/powerauth-server.git`
- Each **"source repository"** has its own unique "repository identifier," for example `powerauth-server`.
- Each source repository contains a folder with all files, which has to be collected. This folder is also called as **"documentation"** or **"docs"** folder.
- Each documentation folder contains **"home file,"** representing a starting page for application's documentation.
- **"Source repository collection"** is a set of source repositories required to build final documentation. 
- **"Repository cache"** is a temporary folder, where all source repositories are cloned (let's use `$REPO_DIR` in examples)
- **"Output folder"** is a destination folder, where the final documentation is prepared (let's use `$OUT_DIR` in examples)
- **"Final documentation"** contains documentation for all applications stored in the output folder. 

The `DocuCheck` tool has three main execution phases: 

1. [Documentation Collection](#1-documentation-collection) 
1. [Links Validation](#2-links-validation)
1. [Additional Operations](#3-additional-operations)


## 1. Documentation collection

The purpose of this step is to download and prepare all documentation-related files into the output folder:

1. Clones all source repositories into repository cache. The repository identifier is the name of the folder.
   - For example: `git clone https://github.com/wultra/powerauth-server.git $REPO_DIR/powerauth-server`
   - If the repository exists in the cache, then the collection of "git checkout" and "git pull" operations are performed on already cloned data 

1. DocuCheck then looks for "docs" folder in the cloned repository and if the folder exists, then copies its content to the output directory. The destination directory has also the repository identifier in the path.
   - So, basically executes `cp $REPO_DIR/powerauth-server/docs $OUT_DIR/powerauth-server`

1. Validates, whether `$OUT_DIR/powerauth-server` contains home file.
   - As a part of this step, the home file (which can be configured per-repository) is renamed to an appropriate target home file name. That's typically `index.md`, but can be changed in global parameters in the configuration. 

1. Removes all unwanted files from `$OUT_DIR`, For example:
   - Various hidden files, like `.DS_Store`, `.gitignore`, etc., which may affect the final webpage generation.
   - The list of ignored files can be configured per source repository.


In the end, the `$OUT_DIR` contains a collection of folders, where each folder contains complete application's documentation. The rest of the `DocuCheck` tasks are performed with this collection of files.


## 2. Links validation

In this phase, `DocuCheck` parses all available Markdown files in `$OUT_DIR` and collects several important attributes per document:

1. Collects all links defined in the document (including links to images)
1. Collects all headers, and creates a list of page anchors (to be able to link to a specific chapter in the document)
1. Collects all inline HTML comments to get an additional meta-data (See [Document Processing](Document-Processing.md#meta-data))

After that, the validation does following simple checks:

- If the link points to the document in the same repository, then validates whether the file exists.
- If the link also contains an anchor (like `#some-chapter`), then also validates whether the destination document contains such chapter.
- If the link points to the document in another repository from the collection, then the link is changed to a relative link to the destination source repository.
  - For example, if `powerauth-webflow/index.md` has a link to `powerauth-server/System-Requirements.md`, then relative `../powerauth-server/System-Requirements.md` is created.
  - Note that the original link must be in the form of full github link, like `https://github.com/wultra/powerauth-server/blob/develop/docs/System-Requirements.md`
- If the link is relative and escapes the original `"docs"` folder, then it signals that the link must point to the source code. In this situation, validator changes the link to point to a right version of the file at github webpage.
  - For example, `[Code.swift](../Sources/Code.swift)` will be translated to `[Code.swift](https://github.com/wultra/some-repo/blob/develop/Sources/Code.swift)` where `develop` depends on actual branch used for the documentation creation.
- If the link points to somewhere else or is email, then keeps the link as it is.

If no error or warning is reported, then you can be sure, that links across the repositories, or links pointing to specific chapters, are all valid.


## 3. Additional operations

In this phase, `DocuCheck` performs some additional tasks:

1. Removes sections of documentation marked for removal (See [Document Processing](Document-Processing.md#meta-data))
1. If the documentation in the repository is created from only one markdown file, then creates `_Sidebar.md` file with an appropriate table of content section (needs to be specified in the configuration).
1. Replaces all first level headers from all markdown files with template, required by our site generator. For example:
   ```md
   # System Requirements
   ```
   will be replaced with
   ```
   ---
   title: System Requirements
   layout: page
   source: https://github.com/...url-to-source-markdown-file...
   ---
   ```
1. Saves all changed documents to the filesystem.

The primary purpose of this phase is to prepare and finalize markdown files to be easily served on our [developers portal](https://developers.wultra.com).