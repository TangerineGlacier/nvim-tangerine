# nvim-tangerine

**nvim-tangerine** is a cutting-edge Neovim plugin that brings intelligent, context-aware code auto-completion to your fingertips using the power of Ollama. Designed with modern developers in mind, this plugin enhances your coding workflow by providing precise, on-demand suggestions that integrate seamlessly with your editor.

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

## Demo

<video controls>
  <source src="assets/demo.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>

## Features

- **Intelligent Auto-Completion:**  
  nvim-tangerine waits for 4 seconds of inactivity in Insert mode to analyze your code context and then contacts an Ollama endpoint for a completion. Only the missing snippet is inserted—nothing extra, nothing distracting.

- **Minimalist Interface:**  
  With a single, elegant notification ("tangerine activated..") upon receiving a suggestion, you stay informed without cluttering your screen with extraneous debug messages.

- **Seamless Integration:**  
  Built with modern Neovim configurations in mind, nvim-tangerine is fully compatible with [lazy.nvim](https://github.com/folke/lazy.nvim) and other popular plugin managers.

- **Effortless Setup:**  
  Designed to work out-of-the-box, nvim-tangerine requires minimal configuration so you can focus on writing code, not tweaking settings.

## Why nvim-tangerine?

In today's fast-paced development environments, efficiency is everything. nvim-tangerine transforms the way you code by leveraging advanced AI-driven completions. It understands the context of your code and provides just the right snippet to complete your thought, reducing keystrokes and streamlining your workflow. Whether you're a seasoned developer or just starting out, nvim-tangerine is your ultimate coding companion.

## Installation

### Using lazy.nvim

If you’re using [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management, simply add the following to your Neovim configuration:

```lua
return {
  {
    "TangerineGlacier/nvim-tangerine", -- Replace with your GitHub username and repository name
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
   The plugin monitors your typing and waits until there’s a brief pause (4 seconds) before capturing the entire code context from your buffer.

2. **AI-Powered Suggestion:**  
   It then constructs an intelligent prompt and sends it to an Ollama endpoint. The model processes your code and returns only the missing snippet required to complete your current line.

3. **Seamless Integration:**  
   Upon receiving a response, you’ll see a concise notification: **"tangerine activated.."**  
   The suggested snippet is then offered as an auto-completion candidate—simply accept it to have your code seamlessly completed.

## Customization

nvim-tangerine works perfectly right out-of-the-box, but if you’re a power user with custom needs, feel free to fork the repository and tweak the code to your heart’s content. We welcome enhancements and feature requests!

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. If you have suggestions, bug fixes, or improvements, please open an issue or submit a pull request. Let’s build something extraordinary together!

## License

This project is licensed under the [MIT License](LICENSE). Use it freely in your projects, contribute to its development, and share it with your fellow developers.

## Acknowledgements

A huge thank you to the developers behind Neovim and Ollama. Their innovation and commitment to open-source have inspired the creation of tools like nvim-tangerine, making a positive impact on the coding community worldwide.

---

Embrace the future of coding with **nvim-tangerine**—where precision meets productivity and every keystroke counts!

Happy coding! 
