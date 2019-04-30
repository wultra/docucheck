# The story behind DocuCheck

Despite the fact, that [Wultra](https://wultra.com) is a small company, we suddenly realized, that we wrote a lot of technical documentation about our products. All that Markdown files were placed across multiple repositories, hosted at github's wiki (per source code repository), so it was quite confusing for our customers to get the right information for the right version of the product. At this point, we decided to create a [dedicated portal for developers](https://developers.wultra.com), which supposed to serve all the documentation at one place, for multiple versions. The [jekyll](https://jekyllrb.com) was the right choice as a tool for a static site generation.

First version of the portal was basically manually created with a minimum automation support. We had a script which cloned all that wiki pages into one folder, then ran a few black-magic regexps to fix the links and then, we had to manually fix all the cross-repository links. That's how the documentation for our [2018.06 Release](https://developers.wultra.com/docs/2018.06/) was born :) 

We quickly realized that this is not the way we want to manage our documentation, so we decided to:

- Move all docs into source code repositories, so we can version documentation together with the code
- Develop a custom tool, which helps to collect and check the documentation at once

On top of that, we had a few additional requirements for our new documentation:

- It should work on github as it is. That means that links from one repository to another should work both on github and on our own portal web-pages.
- If documentation references a source file from the same repository, then the link at portal should point to the properly versioned source file at github.
- We wanted to find and fix all broken links, including links to a specific chapter of the document. 

As you can see, this complex task cannot be achieved with using simple regexps and rename file rules and that's why we started developing the `DocuCheck`. The `Swift` language was selected as an experiment to test, whether it's possible to build a such tool in a limited time (like in 2-3 weeks total). The next reason for that selection was a reason that no `java` developer was available at the time and we did not wanted to lear a next language, like `python` or `ruby`. 

At the end of this story, we have a fully automated tooling that allows us to update the developer portal as frequently as we wish for each release separately. You can check our scripts in [wultra/wultra-developers](https://github.com/wultra/wultra-developers) as a good example for `DocuCheck` integration and usage.