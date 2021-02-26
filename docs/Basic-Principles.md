# Basic Principles

This chapter explains what functionality `DocuCheck` provides and how it works in detail.

## General Terminology

We're using the following terminology in this documentation:

- **"Application"** is one particular product which supposes to be documented. For example "PowerAuth Server."
- **"Source repository"** is a git repository containing source codes and documentation written in Markdown, for one particular application. For example `https://github.com/wultra/powerauth-server.git`
- Each source repository has its own unique **"repository identifier,"** for example `powerauth-server`.
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

1. `DocuCheck` then looks for "docs" folder in the cloned repository and if the folder exists, then copies its content to the output directory. The destination directory has also the repository identifier in the path.
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
1. Collects all inline HTML comments to get an additional [meta-data](#meta-data).

After that, the validation does following simple checks:

- If the link points to the document in the same repository, then validates whether the file exists.
- If the link also contains an anchor (like `#some-chapter`), then also validates whether the destination document contains such chapter.
- If the link points to the document in another repository from the collection, then the link is changed to a relative link to the destination source repository.
  - For example, if `powerauth-webflow/index.md` has a link to `powerauth-server/System-Requirements.md`, then relative `../powerauth-server/System-Requirements.md` is created.
  - Note that the original link must be in the form of full GitHub link, like `https://github.com/wultra/powerauth-server/blob/develop/docs/System-Requirements.md`
- If the link is relative and escapes the original `"docs"` folder, then it signals that the link must point to the source code. In this situation, validator changes the link to point to a right version of the file at GitHub webpage.
  - For example, `[Code.swift](../Sources/Code.swift)` will be translated to `[Code.swift](https://github.com/wultra/some-repo/blob/develop/Sources/Code.swift)` where `develop` depends on actual branch used for the documentation creation.
- If the link points to somewhere else or is email, then keeps the link as it is.

If no error or warning is reported, then you can be sure, that links across the repositories, or links pointing to specific chapters, are all valid.


## 3. Additional operations

In this phase, `DocuCheck` performs some additional tasks:

1. Removes sections of documentation marked for removal (See [Meta-data](#meta-data) chapter)
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

## Meta-data 

`DocuCheck` treats inline HTML comments (e.g. comment which begins and ends at the same line) as a source for meta-data information. Basic format is very simple:

- Multi-line meta-data information:
  ```md
  <!-- begin information -->
  ## Markdown header
  Content captured in meta-data information.
  <!-- end -->
  ```

- Single-line meta-data information:
  ```md
  <!-- marker with params -->
  ```

Multi-line meta-data markers can be combined, but you should close all leves with "end" tag:
```md
<!-- begin meta1 -->
Captured in meta1
<!-- begin meta2 -->
Captured in meta1 and meta2
<!-- marker captured in both multi-line markers -->
<!-- end -->
Also captured in "meta1"
<!-- !! ignore this meta-tag -->
<!-- end -->
``` 

The purpose of meta-data captures is to define regions of text in document, which requires a special processing. For example, if you want to remove a part of document, normally visible at Github, which suppose to not be visible at our development portal.

### Operations based on collected meta-data

Currently only two types of operations are supported:

- Remove multiple lines
- Select Markdown sequence for automatic generation of "Table of contents".
- Add the author to the post.
- Override the sidebar with custom file.

#### Remove multiple lines

If you want to remove a part of document from final documentation, use following tags:
```md
# Chapter 3

This part will be available at developer portal.
<!-- begin remove -->
This whole sequence will be removed and not visible at developers portal.
<!-- end -->
```

#### Generate TOC

If documentation is composed from one single document, then meta-data information allows you to specify section with "Table of content", which can be used to generate `_Sidebar.md` for that repository. Use following sequence to define TOC:

```md
# Document title
<!-- begin TOC -->
- [Chapter 1](#chapter-1)
- [Chapter 2](#chapter-2)
<!-- end -->
```

A good example is [SSL Pinning for iOS](https://github.com/wultra/ssl-pinning-ios#docucheck-keep-link). You can see, that document visible at GitHub contains TOC at the beginning, but [version at our portal](https://github.com/wultra/ssl-pinning-ios) has that section available in the sidebar.

#### Changing Page Template

In case a particular documentation page desires a specific layout, you can specify a custom template by using the `TEMPLATE` metadata:

```md
<!-- TEMPLATE tutorials -->
```

The `TEMPLATE` metadata require exactly one attribute that represents the template name. The value is filled in to the `layout:` portion of Jekyll front matter without any interpretation (you are responsible for providing an existing layout name). If no template is specified in a particular documentation page, the default `page` template is used.

#### Add the Author to the Post

You can add an information about an author and article publishing date to the sidebar using a simple one-line tag:

```md
<!-- AUTHOR joshis_tweets 2020-05-04T00:00:00Z -->
```

The additional author information is then picked from the `_data/authors.yaml` file based on the author identification.

#### Override the Sidebar With Custom File

In case you would like to include a custom sidebar in the document, you can do so via:

```md
<!-- SIDEBAR _Sidebar_Server.md sticky -->
```

The first parameter defines a name of the file to include (in the same folder as the main document). The second parameter defines the sidebar position - `sticky` means that the sidebar should remain visible, any other value (or empty parameter) means that the sidebar scrolls with the content. Use `sticky` value with caution for reasonably small sidebars - if the sidebar is too high, content may not be reachable.

#### Code tabs

You can format code examples written in different languages into tabs, that user can switch between. For example, let say, you want to write the same example in Swift and Objective-C code:

~~~md
<!-- begin codetabs Swift Objective-C -->
```swift
// Example in Swift
let object = Object()
```
```objc
// Example in Objective-C
NSObject * object = [[NSObject alloc] init];
```
<!-- end -->
~~~

The number of parameters used in `codetabs`  defines the number of tabs visible in the final documentation. Make sure that the number of code blocks match the number of tab names and there's no other markdown formatting between the code blocks.

#### Arbitrary tabs

In case that [code tabs](#code-tabs) doesn't fit your formatting requirements, then use  `tabs` metadata marker and specify each tab with `tab`. For example:

~~~md
<!-- begin tabs -->
<!-- tab Swift -->
Use following code for swift:
```swift
let object = Object()
```
<!-- tab Objective-C -->
Use following code for Objective-C:
```objc
NSObject * object = [[NSObject alloc] init];
```
<!-- end -->
~~~

#### Info boxes

You can use information boxes with a custom styling to highlight some important information. For example: 

~~~md
<!-- begin box warning -->
All your base are belong to us.
<!-- end -->
~~~

The code above will be displayed as:

<!-- begin box warning -->
All your base are belong to us.
<!-- end -->

The following styles are supported: `info`,  `warning` and `success`.
