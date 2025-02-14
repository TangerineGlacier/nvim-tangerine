
# nvim-tangerine
<div align="center">
  <img src="/assets/tangerine.jpg" alt="Tangerine" width="200"/>
</div>


**nvim-tangerine** is a cutting-edge Neovim plugin that brings intelligent, context-aware code auto-completion to your fingertips using the power of Ollama. Designed with modern developers in mind, this plugin enhances your coding workflow by providing precise, on-demand suggestions that integrate seamlessly with your editor.

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

## Demo

![Demo GIF](assets/demo.gif)

## Features

- **Intelligent Auto-Completion:**  
  nvim-tangerine waits for 4 seconds of inactivity in Insert mode to analyze your code context and then contacts an Ollama endpoint for a completion. Only the missing snippet is inserted—nothing extra, nothing distracting.

- **Context-Aware Intelligence:**  
  The plugin leverages both **project context** and **file context** by capturing your entire file's content before generating suggestions. To enhance this process, nvim-tangerine uses [Tree-sitter](https://github.com/tree-sitter/tree-sitter) to parse and understand the structure of your code, ensuring that completions are both syntactically and semantically relevant. Additionally, the `:TangerineDescribeFile` command sends the full file to Ollama for a concise summary of its functionality and purpose.

- **File-Type Specific Behavior:**  
  Recognizing that not all file types benefit from auto-completion, nvim-tangerine automatically disables auto-completion for files with extensions such as `.sql` and `.md`. This targeted approach keeps your workflow clean and efficient in contexts where suggestions might be distracting.

- **Minimalist Interface:**  
  With a single, elegant notification ("tangerine activated..") upon receiving a suggestion, you stay informed without cluttering your screen with extraneous debug messages.

- **Seamless Integration:**  
  Built with modern Neovim configurations in mind, nvim-tangerine is fully compatible with [lazy.nvim](https://github.com/folke/lazy.nvim) and other popular plugin managers.

- **Effortless Setup:**  
  Designed to work out-of-the-box, nvim-tangerine requires minimal configuration so you can focus on writing code, not tweaking settings.

## Why nvim-tangerine?

In today's fast-paced development environments, efficiency is everything. nvim-tangerine transforms the way you code by leveraging advanced AI-driven completions. It understands the broader context of your file and project—enhanced by Tree-sitter's parsing capabilities—providing just the right snippet to complete your thought, reducing keystrokes and streamlining your workflow. Whether you're a seasoned developer or just starting out, nvim-tangerine is your ultimate coding companion.

## Installation

### Using lazy.nvim

If you’re using [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management, simply add the following to your Neovim configuration:

```lua
return {
  {
    "TangerineGlacier/nvim-tangerine",
    config = function()
      require("nvim-tangerine").setup()
    end,
  },
}
```

### Manual Installation

1. **Clone the Repository:**  
   Clone nvim-tangerine into your Neovim plugin directory (e.g., `~/.config/nvim/pack/plugins/start/`):

   ```sh
   git clone https://github.com/TangerineGlacier/nvim-tangerine.git ~/.config/nvim/pack/plugins/start/nvim-tangerine
   ```

2. **Configure in Neovim:**  
   Add the following line to your Neovim configuration file (e.g., `init.lua`):

   ```lua
   require("nvim-tangerine").setup()
   ```

## How It Works

nvim-tangerine is built to enhance your coding experience by smartly integrating with your workflow:

1. **Context Capture:**  
   The plugin monitors your typing and waits until there’s a brief pause (4 seconds) before capturing the entire file content—providing both file and project context. Leveraging [Tree-sitter](https://github.com/tree-sitter/tree-sitter), it can accurately parse your code to extract structural and semantic information, making the generated suggestions highly relevant.

2. **AI-Powered Suggestion:**  
   It constructs an intelligent prompt—including the enriched file context—and sends it to an Ollama endpoint. The model processes your code and returns only the missing snippet required to complete your current line.

3. **Seamless Integration:**  
   Upon receiving a response, you’ll see a concise notification: **"tangerine activated.."**  
   The suggested snippet is then offered as an auto-completion candidate.

4. **File Description:**  
   With the `:TangerineDescribeFile` command, the plugin sends the entire file to Ollama and retrieves a clean, concise description of your file’s functionality, purpose, and notable features—all while keeping your code intact.

## Shortcuts & Commands

nvim-tangerine provides a few handy shortcuts and commands to streamline your workflow:

- **Accept Suggestion:**  
  When a ghost suggestion is visible in Insert mode, press ``Ctrl+Shift+Tab`` to accept and insert the missing snippet into your code.  
  (If no suggestion is present, the key sequence behaves as a normal ``<C-S-Tab>``.)

- **Toggle Auto-Completion:**  
  Use the command ``:TangerineAuto on`` to enable auto-completion and ``:TangerineAuto off`` to disable it.  
  *Note:* Auto-completion is automatically disabled for file extensions like ``.sql`` and ``.md``.

- **Describe File:**  
  Run ``:TangerineDescribeFile`` to generate a concise description of your current file. This command sends the entire file content to Ollama and displays a summary in a floating window.

## Context-Aware Intelligence

nvim-tangerine goes beyond basic auto-completion by understanding both the **project context** and **file context**:
- **Project Context:**  
  By considering the overall structure and style of your codebase, the plugin ensures that suggestions align with your project's conventions.
- **File Context:**  
  Before generating suggestions, the plugin sends your complete file content to Ollama, making sure that the auto-completion is informed by everything you’re working on. The integration with [Tree-sitter](https://github.com/tree-sitter/tree-sitter) further refines this process by accurately parsing your code to extract meaningful context.

This holistic approach results in smarter, more relevant completions that help you write code faster and with greater accuracy.

## File-Type Specific Behavior

Not all file types need auto-completion. nvim-tangerine smartly disables auto-completion for file extensions like ``.sql`` and ``.md``, where such suggestions may not be beneficial. This feature helps maintain an uncluttered and efficient coding experience across various file types.

## Customization

nvim-tangerine works perfectly right out-of-the-box, but if you’re a power user with custom needs, feel free to fork the repository and tweak the code to your heart’s content. We welcome enhancements and feature requests!

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. If you have suggestions, bug fixes, or improvements, please open an issue or submit a pull request. Let’s build something extraordinary together!

## License

This project is licensed under the [MIT License](LICENSE). Use it freely in your projects, contribute to its development, and share it with your fellow developers.

## Acknowledgements

A huge thank you to the developers behind Neovim, Ollama, and [Tree-sitter](https://github.com/tree-sitter/tree-sitter). Their innovation and commitment to open-source have inspired the creation of tools like nvim-tangerine, making a positive impact on the coding community worldwide.

---

Embrace the future of coding with **nvim-tangerine**—where precision meets productivity, context is king, and every keystroke counts!

`Happy coding!`
