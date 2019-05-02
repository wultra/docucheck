# Documentation Tool

The `DocuCheck` is a command line tool written in `Swift`, that collects and validates documentation written in [Markdown](https://guides.github.com/features/mastering-markdown/). The tool does following main tasks:

- Collects documentation from various remote sources (typically from a remote git repository).
- Copies all predefined folders containing documentation into one predefined folder.
- Validates all links pointing to another documents or to anchors in the documents.
- Patches all documents to be easily served on Wultra's [developers portal](https://developers.wultra.com).

The tool was developed for Wultra's internal purposes, so it's highly specialized for what we need for our own documentation.


## Prerequisites

The `DocuCheck` has following requirements:

- `macOS` (or compatible) computer
- `Swift 5` compiler (Xcode 10.2+)
- `git` installed on the system


## Installation

The `DocuCheck` tool installation is quite simple. You need to clone this repository and build the executable:

- To clone the repository, type:
  ```sh
  git clone https://github.com/wultra/docucheck.git
  cd docucheck
  ```

- To build the executable, type:
  ```sh
  swift build -c release 
  cp .build/release/DocuCheck ${dest}
  ```
  Where `${dest}` is your destination folder, where you want to store the final executable. For the rest of the documentation we assume that `DocuCheck` command is available at current `PATH`, so it can be simply executed.

- To run the executable without copy to the predefined directory, simply run:
  ```sh
  swift run DocuCheck ${parameters}
  ```
  Where `${parameters}` are parameters of the tool. For example `-h`. 

As you can see, `DocuCheck` is using Swift Package Manager to build and execute itself, so you can simply integrate the tool into your projects, managed by the SPM. To do this, please check the official [Swift Package Manager documentation](https://swift.org/package-manager/) for more details.



## Usage

Before you start using the tool, please check following documents:

- [Basic Principles](Basic-Principles.md) page makes an deeper introduction what `DocuCheck` does and how.
- [Configuration File](Configuration-File.md) page describes configuration file, required by the tool.
- [Writing Wultra's Documentation](Writing-Wultras-Documentation.md) page describes how to properly document Wultra's projects.
- [Story behind DocuCheck](Story-Behind.md) page describes motivations why we developed this tool.

The basic usage of the tool is quite simple:

- To collect and validate the documentation, type:
  ```sh
  DocuCheck -c ${path_to_config}
  ```
  Where `${path_to_config}` is path to [JSON configuration](Configuration-File.md) file.
  
- To show help embedded in the tool, type:
  ```sh
  DocuCheck -h
  ```
  
- Check [Usage page](Usage.md) for more information about command line interface. 


## Known Bugs

For the list of known bugs, please visit [Known Bugs](Known-Bugs.md) page, which contains current list of all known issues in the tool and possible workarounds.


## License

All sources are licensed using Apache 2.0 license, you can use them with no restriction. If you are using this tool, please let us know. We will be happy to share and promote your project.


## Contact

If you need any assistance, do not hesitate to drop us a line at [hello@wultra.com](mailto:hello@wultra.com) or our official [gitter.im/wultra](https://gitter.im/wultra) channel.
