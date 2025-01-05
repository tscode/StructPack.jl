
# Make Pack accessible
push!(LOAD_PATH, "../src/")

using Documenter, Pack

makedocs(
  sitename="Pack.jl Documentation",
  pages = [
      "Overview" => "index.md",
      "Usage" => "usage.md",
      "Formats" => "formats.md",
      "Scopes" => "scopes.md",
      "API Reference" => "reference.md",
  ]
)
