# Known Bugs

This page is intended to provide information on known bugs. Please feel free to contribute more known bugs and their work arounds as they are discovered. 


### DocuCheck doesn't track renamed files

The tool doesn't track what file was renamed during the documentation collection phase. The result of this design flaw is that if there's an error, or warning in "home" file, this is wrongly reported under the final name. That's typically `index.md`. For example, if your "home" file is "Readme.md", then the warning is typically reported as:
````
DocuCheck: WARNING: other-repo/index.md:182: Link [Your Link](https://github.com/wultra/repo/blob/develop/docs/Some-File.md) points to unknown file in the repository.
````
In this case, you need to interpret that `index.md` as `Readme.md`


### git clone via ssh

Downlading git remotes via `ssh` is not supported yet. This will be fixed in some future versions of the tool.


### Links to source codes are not validated

If some link points to a source code in the same repository (like `../Sources/YourFile.swift` if your docs are in `docs` folder), then this link is not validated. 


### Forbidden characters in filenames

Due to limitations of Markdown parser, you should avoid using following characters in filenames:

- `(`, `)`, `[`, `]`, `{`, `}` - various brackets
- ` `  - space character

In general, you should limit filenames to alphanumeric characters, dot, column and dash. Otherwise you have to escape such characters and that's quite impractical. The parser can detect some of problematic sequences characters, but it's recommended do simply do not use such characters.