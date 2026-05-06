class Palimpsest < Formula
  desc "Persistent memory layer for Claude Code & GitHub Copilot, built on Obsidian"
  homepage "https://github.com/Sokrix/palimpsest"
  url "https://github.com/Sokrix/palimpsest/archive/refs/tags/v0.1.0.tar.gz"
  # After tagging v0.1.0 on GitHub, compute with:
  #   curl -sL https://github.com/Sokrix/palimpsest/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
  sha256 "REPLACE_WITH_TARBALL_SHA256_AFTER_TAGGING"
  license "Apache-2.0"

  depends_on "python@3"
  depends_on :macos

  def install
    # Ship the runtime tree under libexec/ so the CLI can find it via
    # PALIMPSEST_HOME_OVERRIDE without polluting share/.
    libexec.install "templates", "lib", "install.sh", "VERSION"

    # The CLI itself goes in bin/. Bake the libexec path into the script so
    # it doesn't need to probe at runtime.
    bin.install "bin/palimpsest"
    inreplace bin/"palimpsest",
              'PALIMPSEST_HOME_OVERRIDE=""',
              "PALIMPSEST_HOME_OVERRIDE=\"#{libexec}\""
  end

  def caveats
    <<~EOS
      Next steps:
        1. Run the interactive setup:    palimpsest install
        2. Health-check the install:     palimpsest doctor
        3. List all commands:            palimpsest help

      The setup wizard creates an Obsidian vault and installs slash
      commands for Claude Code and/or GitHub Copilot.
    EOS
  end

  test do
    assert_match(/^palimpsest v\d+\.\d+\.\d+/, shell_output("#{bin}/palimpsest version"))
    assert_match "Usage: palimpsest", shell_output("#{bin}/palimpsest help")
  end
end
