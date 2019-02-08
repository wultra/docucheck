import Foundation

print("Hello, world! \(CommandLine.arguments)")

Console.messageHeader("This is a test")
Console.warning("You should be more careful!")
Console.messageLine()
Console.message("What do you think?")
Console.messageLine()

Console.error("That went wrong!")
Console.debug("This will not be displayed.")

let git1 = Cmd("git")
let git2 = Cmd("git")

git1.run(with: ["--version"])
git2.run(with: ["status"])

let ls = Cmd("ls")

ls.run(with: ["-la"])
