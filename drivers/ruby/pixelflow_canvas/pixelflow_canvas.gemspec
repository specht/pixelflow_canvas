# frozen_string_literal: true

require_relative "lib/pixelflow_canvas/version"

Gem::Specification.new do |spec|
  spec.name = "pixelflow_canvas"
  spec.version = PixelflowCanvas::VERSION
  spec.authors = ["Michael Specht"]
  spec.email =    ["micha.specht@gmail.com"]
  spec.licenses = ['GPL-3.0-only']

  spec.summary = "Ruby driver for the Pixelflow Canvas VS Code extension."
  spec.description = "Use a virtual CRT for old school graphics programming, in VS Code, from Ruby."
  spec.homepage = "https://github.com/specht/pixelflow_canvas_ruby"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/specht/pixelflow_canvas_ruby"
  spec.metadata["changelog_uri"] = "https://github.com/specht/pixelflow_canvas_ruby"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
