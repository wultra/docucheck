# Known Bugs

This page is intended to provide information on known bugs. Please feel free to contribute more known bugs and their work arounds as they are discovered. 


### git clone via ssh

Downlading git remotes via `ssh` is not supported yet. This will be fixed in some future versions of the tool.


### Link to Readme.md in another repository

Links to Readme.md located in another repository, in form of full path, will not work. For example:

- `[Link to mobile SDK](https://github.com/wultra/powerauth-mobile-sdk/blob/develop/docs/Readme.md)` - doesn't work
- `[Link to mobile SDK](https://github.com/wultra/powerauth-mobile-sdk)` - should work as a workaround


### Links to source codes are not validated

If some link points to a source code in the same repository (like `../Sources/YourFile.swift` if your docs are in `docs` folder), then this link is not validated. 


### Forbidden characters in filenames

Due to limitations of Markdown parser, you should avoid using following characters in filenames:

- `(`, `)`, `[`, `]`, `{`, `}` - various brackets
- ` `  - space character

In general, you should limit filenames to alphanumeric characters, dot, column and dash. Otherwise you have to escape such characters and that's quite impractical. The parser can detect some of problematic sequences characters, but it's recommended do simply do not use such characters.