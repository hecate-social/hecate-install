return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    -- Expanded collection of inspirational quotes
    local quotes = {
      -- Programming & Tech Quotes
      { text = "The only way to do great work is to love what you do.", author = "Steve Jobs" },
      { text = "Code is like humor. When you have to explain it, it's bad.", author = "Cory House" },
      { text = "First, solve the problem. Then, write the code.", author = "John Johnson" },
      { text = "Experience is the name everyone gives to their mistakes.", author = "Oscar Wilde" },
      { text = "Java is to JavaScript what car is to Carpet.", author = "Chris Heilmann" },
      { text = "Knowledge is power.", author = "Francis Bacon" },
      {
        text = "Sometimes it pays to stay in bed on Monday, rather than spending the rest of the week debugging Monday's code.",
        author = "Dan Salomon",
      },
      {
        text = "Perfection is achieved not when there is nothing more to add, but rather when there is nothing more to take away.",
        author = "Antoine de Saint-Exupery",
      },
      { text = "Code never lies, comments sometimes do.", author = "Ron Jeffries" },
      {
        text = "A language that doesn't affect the way you think about programming is not worth knowing.",
        author = "Alan Perlis",
      },
      {
        text = "The best programs are written so that computing machines can perform them quickly and so that human beings can understand them clearly.",
        author = "Donald Knuth",
      },
      {
        text = "Always code as if the guy who ends up maintaining your code will be a violent psychopath who knows where you live.",
        author = "John Woods",
      },
      { text = "Programming isn't about what you know; it's about what you can figure out.", author = "Chris Pine" },
      { text = "The computer was born to solve problems that did not exist before.", author = "Bill Gates" },
      {
        text = "Programming is the art of telling another human being what one wants the computer to do.",
        author = "Donald Knuth",
      },
      {
        text = "The most important property of a program is whether it accomplishes the intention of its user.",
        author = "C.A.R. Hoare",
      },
      { text = "Debugging is twice as hard as writing the code in the first place.", author = "Brian Kernighan" },
      { text = "Make it work, make it right, make it fast.", author = "Kent Beck" },
      { text = "The function of good software is to make the complex appear to be simple.", author = "Grady Booch" },
      {
        text = "Any fool can write code that a computer can understand. Good programmers write code that humans can understand.",
        author = "Martin Fowler",
      },
      {
        text = "Programs must be written for people to read, and only incidentally for machines to execute.",
        author = "Harold Abelson",
      },
      { text = "The best error message is the one that never shows up.", author = "Thomas Fuchs" },
      { text = "Software is a great combination between artistry and engineering.", author = "Bill Gates" },
      { text = "Clean code always looks like it was written by someone who cares.", author = "Robert C. Martin" },
      { text = "The best way to predict the future is to implement it.", author = "Alan Kay" },
      { text = "Talk is cheap. Show me the code.", author = "Linus Torvalds" },
      {
        text = "There are only two hard things in Computer Science: cache invalidation and naming things.",
        author = "Phil Karlton",
      },
      { text = "It's not a bug – it's an undocumented feature.", author = "Anonymous" },
      {
        text = "The most disastrous thing that you can ever learn is your first programming language.",
        author = "Alan Kay",
      },
      {
        text = "A good programmer is someone who always looks both ways before crossing a one-way street.",
        author = "Doug Linder",
      },
      {
        text = "Programming today is a race between software engineers striving to build bigger and better idiot-proof programs, and the Universe trying to produce bigger and better idiots.",
        author = "Rick Cook",
      },
      { text = "Before software can be reusable it first has to be usable.", author = "Ralph Johnson" },
      {
        text = "The best thing about a boolean is even if you are wrong, you are only off by a bit.",
        author = "Anonymous",
      },
      {
        text = "Without requirements or design, programming is the art of adding bugs to an empty text file.",
        author = "Louis Srygley",
      },
      {
        text = "Measuring programming progress by lines of code is like measuring aircraft building progress by weight.",
        author = "Bill Gates",
      },
      {
        text = "Walking on water and developing software from a specification are easy if both are frozen.",
        author = "Edward V. Berard",
      },
      {
        text = "The first 90% of the code accounts for the first 90% of the development time. The remaining 10% of the code accounts for the other 90% of the development time.",
        author = "Tom Cargill",
      },
      {
        text = "Commenting your code is like cleaning your bathroom — you never want to do it, but it really does create a more pleasant experience for you and your guests.",
        author = "Ryan Campbell",
      },
      { text = "Programming is not about typing, it's about thinking.", author = "Rich Hickey" },
      {
        text = "The cheapest, fastest, and most reliable components are those that aren't there.",
        author = "Gordon Bell",
      },

      -- General Inspirational Quotes
      { text = "Innovation distinguishes between a leader and a follower.", author = "Steve Jobs" },
      { text = "In order to be irreplaceable, one must always be different.", author = "Coco Chanel" },
      { text = "Simplicity is the ultimate sophistication.", author = "Leonardo da Vinci" },
      { text = "If you want to go fast, go alone. If you want to go far, go together.", author = "African Proverb" },
      { text = "The only impossible journey is the one you never begin.", author = "Tony Robbins" },
      {
        text = "Success is not final, failure is not fatal: it is the courage to continue that counts.",
        author = "Winston Churchill",
      },
      { text = "The way to get started is to quit talking and begin doing.", author = "Walt Disney" },
      { text = "Don't be afraid to give up the good to go for the great.", author = "John D. Rockefeller" },
      { text = "If you really look closely, most overnight successes took a long time.", author = "Steve Jobs" },
      { text = "The future belongs to those who believe in the beauty of their dreams.", author = "Eleanor Roosevelt" },
      { text = "It is during our darkest moments that we must focus to see the light.", author = "Aristotle" },
      { text = "Believe you can and you're halfway there.", author = "Theodore Roosevelt" },
      {
        text = "The only person you are destined to become is the person you decide to be.",
        author = "Ralph Waldo Emerson",
      },
      { text = "I have not failed. I've just found 10,000 ways that won't work.", author = "Thomas A. Edison" },
      { text = "A person who never made a mistake never tried anything new.", author = "Albert Einstein" },
      {
        text = "The greatest glory in living lies not in never falling, but in rising every time we fall.",
        author = "Nelson Mandela",
      },
      { text = "Life is what happens to you while you're busy making other plans.", author = "John Lennon" },
      { text = "The future belongs to those who prepare for it today.", author = "Malcolm X" },
      {
        text = "What lies behind us and what lies before us are tiny matters compared to what lies within us.",
        author = "Ralph Waldo Emerson",
      },
      { text = "You miss 100% of the shots you don't take.", author = "Wayne Gretzky" },
    }

    -- Function to fetch quote from API
    local function fetch_quote_from_api()
      -- Use random endpoint instead of today to get different quotes
      local cmd = "curl -s 'https://zenquotes.io/api/random' | head -1"
      local handle = io.popen(cmd)
      if handle then
        local result = handle:read("*a")
        handle:close()

        if result and result ~= "" then
          -- Parse JSON response (basic parsing for this specific API)
          local quote_match = result:match('"q":"([^"]+)"')
          local author_match = result:match('"a":"([^"]+)"')

          if quote_match and author_match then
            return {
              text = quote_match:gsub("\\u%d%d%d%d", ""), -- Remove unicode escapes
              author = author_match,
            }
          end
        end
      end
      return nil
    end

    -- Function to get a quote (tries API first, falls back to local collection)
    local function get_quote_of_the_day()
      -- Try to get quote from API first
      local api_quote = fetch_quote_from_api()
      if api_quote then
        return api_quote
      end

      -- Fallback to local collection with better randomization
      -- Use current time + process ID for more randomness
      local seed = os.time() + (os.clock() * 1000000) % 1000000
      math.randomseed(seed)

      -- Do multiple random calls to improve distribution
      for i = 1, 3 do
        math.random()
      end

      local quote = quotes[math.random(#quotes)]
      return quote
    end

    -- Function to wrap text to fit within specified width
    local function wrap_text(text, width)
      local lines = {}
      local current_line = ""

      for word in text:gmatch("%S+") do
        if #current_line + #word + 1 <= width then
          if current_line == "" then
            current_line = word
          else
            current_line = current_line .. " " .. word
          end
        else
          if current_line ~= "" then
            table.insert(lines, current_line)
          end
          current_line = word
        end
      end

      if current_line ~= "" then
        table.insert(lines, current_line)
      end

      return lines
    end

    -- Custom ASCII art banner with BEAM on top, CAMPUS on bottom, and quote
    local function get_header()
      local quote = get_quote_of_the_day()
      local quote_lines = wrap_text('"' .. quote.text .. '"', 55)
      local author_line = "— " .. quote.author

      -- BEAM section (will use default header color)
      local beam_section = {
        "                                                           ",
        "                                                           ",
        "        ██████╗ ███████╗ █████╗ ███╗   ███╗               ",
        "        ██╔══██╗██╔════╝██╔══██╗████╗ ████║               ",
        "        ██████╔╝█████╗  ███████║██╔████╔██║               ",
        "        ██╔══██╗██╔══╝  ██╔══██║██║╚██╔╝██║               ",
        "        ██████╔╝███████╗██║  ██║██║ ╚═╝ ██║               ",
        "        ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝               ",
        "                                                           ",
      }

      -- CAMPUS section (will use different color)
      local campus_section = {
        "    ██████╗ █████╗ ███╗   ███╗██████╗ ██╗   ██╗███████╗   ",
        "   ██╔════╝██╔══██╗████╗ ████║██╔══██╗██║   ██║██╔════╝   ",
        "   ██║     ███████║██╔████╔██║██████╔╝██║   ██║███████╗   ",
        "   ██║     ██╔══██║██║╚██╔╝██║██╔═══╝ ██║   ██║╚════██║   ",
        "   ╚██████╗██║  ██║██║ ╚═╝ ██║██║     ╚██████╔╝███████║   ",
        "    ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝      ╚═════╝ ╚══════╝   ",
        "                                                           ",
        "                                                           ",
      }

      -- Combine sections and add quotes
      local header = {}

      -- Add BEAM section
      for _, line in ipairs(beam_section) do
        table.insert(header, line)
      end

      -- Add CAMPUS section
      for _, line in ipairs(campus_section) do
        table.insert(header, line)
      end

      -- Add quote lines with proper centering
      for _, line in ipairs(quote_lines) do
        local padding = math.floor((59 - #line) / 2)
        local centered_line = string.rep(" ", padding) .. line
        table.insert(header, centered_line)
      end

      -- Add author line with proper centering
      local author_padding = math.floor((59 - #author_line) / 2)
      local centered_author = string.rep(" ", author_padding) .. author_line
      table.insert(header, centered_author)
      table.insert(header, "                                                           ")

      return header, beam_section, campus_section
    end

    -- Create custom sections for different colored headers
    local header, beam_section, campus_section = get_header()

    -- Define custom highlight groups
    vim.api.nvim_set_hl(0, "DashboardBeam", { fg = "#7aa2f7" }) -- Blue color for BEAM
    vim.api.nvim_set_hl(0, "DashboardCampus", { fg = "#9ece6a" }) -- Green color for CAMPUS
    vim.api.nvim_set_hl(0, "DashboardQuote", { fg = "#bb9af7" }) -- Purple color for quotes

    -- Create sections with different highlight groups
    local beam_header = {
      type = "text",
      val = beam_section,
      opts = {
        position = "center",
        hl = "DashboardBeam",
      },
    }

    local campus_header = {
      type = "text",
      val = campus_section,
      opts = {
        position = "center",
        hl = "DashboardCampus",
      },
    }

    -- Get quote separately for different styling
    local quote = get_quote_of_the_day()
    local quote_lines = wrap_text('"' .. quote.text .. '"', 55)
    local author_line = "— " .. quote.author

    local quote_section_lines = {}
    for _, line in ipairs(quote_lines) do
      local padding = math.floor((59 - #line) / 2)
      local centered_line = string.rep(" ", padding) .. line
      table.insert(quote_section_lines, centered_line)
    end
    local author_padding = math.floor((59 - #author_line) / 2)
    local centered_author = string.rep(" ", author_padding) .. author_line
    table.insert(quote_section_lines, centered_author)
    table.insert(quote_section_lines, "                                                           ")

    local quote_header = {
      type = "text",
      val = quote_section_lines,
      opts = {
        position = "center",
        hl = "DashboardQuote",
      },
    }

    -- Custom buttons
    dashboard.section.buttons.val = {
      dashboard.button("f", " " .. " Find file", ":FzfLua files <CR>"),
      dashboard.button("n", " " .. " New file", ":ene <BAR> startinsert <CR>"),
      dashboard.button("r", " " .. " Recent files", ":FzfLua oldfiles <CR>"),
      dashboard.button("g", " " .. " Find text", ":FzfLua live_grep <CR>"),
      dashboard.button("c", " " .. " Config", ":e $MYVIMRC <CR>"),
      dashboard.button("s", " " .. " Restore Session", [[:lua require("persistence").load() <cr>]]),
      dashboard.button("l", "󰒲 " .. " Lazy", ":Lazy<CR>"),
      dashboard.button("q", " " .. " Quit", ":qa<CR>"),
    }

    -- Custom footer
    local function footer()
      return "🚀 Happy Coding!"
    end

    dashboard.section.footer.val = footer()

    dashboard.section.footer.opts.hl = "Type"
    dashboard.section.buttons.opts.hl = "Keyword"

    -- Configure the layout with custom sections
    dashboard.config.layout = {
      { type = "padding", val = 2 },
      beam_header,
      campus_header,
      quote_header,
      { type = "padding", val = 2 },
      dashboard.section.buttons,
      dashboard.section.footer,
    }

    dashboard.opts.opts.noautocmd = true
    alpha.setup(dashboard.opts)
  end,
  dependencies = { "nvim-tree/nvim-web-devicons" },
}
