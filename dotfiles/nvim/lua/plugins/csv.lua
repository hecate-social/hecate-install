return {
"chrisbra/csv.vim",
ft = {
    "csv",
    "tsv",
},
init = function()
    -- Disable line wrapping for CSV files
    vim.g.csv_no_wrap = 1
    -- Maximum number of columns to highlight
    vim.g.csv_max_cols = 100
    -- Default highlight color for odd/even columns
    vim.g.csv_odd_column_color = 'CSVOdd'
    vim.g.csv_even_column_color = 'CSVEven'
end,
keys = {
    { "<leader>cs", "<cmd>CSVSort<cr>", desc = "Sort CSV by column" },
    { "<leader>ch", "<cmd>CSVHiCol<cr>", desc = "Highlight CSV columns" },
    { "<leader>ct", "<cmd>CSVTabularize<cr>", desc = "Tabularize CSV" },
    { "<leader>cd", "<cmd>CSVDelColumn<cr>", desc = "Delete CSV column" },
    { "H", "<cmd>CSVNextCol<cr>", desc = "Next CSV column" },
    { "L", "<cmd>CSVPrevCol<cr>", desc = "Previous CSV column" },
},
}

