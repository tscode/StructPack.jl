
# Make StructPack accessible
push!(LOAD_PATH, "../src/")

using Documenter, StructPack

makedocs(
  sitename="StructPack.jl Documentation",
  pages = [
      "Overview" => "index.md",
      "Usage" => "usage.md",
      "Formats" => "formats.md",
      "Context" => "context.md",
      "The @pack macro" => "macro.md",
      "API Reference" => "reference.md",
  ]
)

deploydocs(
    repo = "github.com/tscode/StructPack.jl.git",
)
