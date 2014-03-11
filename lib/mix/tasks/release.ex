defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Examples

    mix release
    mix release clean

  """
  @shortdoc "Build a release for the current mix application."

  use Mix.Task

  @_MAKEFILE "Makefile"
  @_RELXCONF "relx.config"
  @_RUNNER   "runner"
  @_NAME     "{{{PROJECT_NAME}}}"
  @_VERSION  "{{{PROJECT_VERSION}}}"

  def run(args) do
    # Ensure this isn't an umbrella project
    if Mix.Project.umbrella? do
      raise Mix.Error, message: "Umbrella projects are not currently supported!"
    end
    # Collect release configuration
    config = [ relfiles_path:   Path.join([__DIR__, "..", "..", "..", "priv"]) |> Path.expand,
               project_name:    Mix.project |> Keyword.get(:app) |> atom_to_binary,
               project_version: Mix.project |> Keyword.get(:version) ]
    cond do
      # Clean up all release-related files
      "clean" in args ->
        do_cleanup
      # Generate a release
      true ->
        config
        |> ensure_makefile
        |> ensure_relx_config
        |> ensure_runner
        |> execute_release

        success "Your release is ready!"
      end
  end

  defp ensure_makefile([relfiles_path: relfiles_path, project_name: name, project_version: _] = config) do
    info "Generating Makefile..."
    source = Path.join(relfiles_path, @_MAKEFILE)
    # Destination is the root
    dest   = Path.join(File.cwd!, @_MAKEFILE)
    case File.exists?(dest) do
      # If the makefile has already been generated, skip generation
      true ->
        # Return the project config after we're done
        config
      # Otherwise, read in Makefile, replace the placeholders, and write it to the project root
      _ ->
        contents = File.read!(source) |> String.replace(@_NAME, name)
        File.write!(dest, contents)
        # Return the project options after we're done
        config
    end
  end

  defp ensure_relx_config([relfiles_path: relfiles_path, project_name: name, project_version: version] = config) do
    info "Generating relx.config"
    source = Path.join([relfiles_path, "rel", @_RELXCONF])
    base   = Path.join(File.cwd!, "rel")
    dest   = Path.join(base, @_RELXCONF)
    # Ensure destination base path exists
    File.mkdir_p!(base)
    case File.exists?(dest) do
      # If the config has already been generated, skip generation
      true ->
        # Return the project config after we're done
        config
      # Otherwise, read in relx.config, replace placeholders, and write to the destination in the project root
      _ ->
        contents = File.read!(source) 
          |> String.replace(@_NAME, name)
          |> String.replace(@_VERSION, version)
        File.write!(dest, contents)
        # Return the project config after we're done
        config
    end
  end

  defp ensure_runner([relfiles_path: relfiles_path, project_name: name, project_version: version] = config) do
    info "Generating runner..."
    source = Path.join([relfiles_path, "rel", "files", @_RUNNER])
    base   = Path.join([File.cwd!, "rel", "files"])
    dest   = Path.join(base, @_RUNNER)
    # Ensure destination base path exists
    File.mkdir_p!(base)
    case File.exists?(dest) do
      # If the runner has already been generated, skip generation
      true ->
        # Return the project config after we're done
        config
      # Otherwise, read in the runner, replace placeholders, and write to the destination in the project root
      _ ->
        contents = File.read!(source)
          |> String.replace(@_NAME, name)
          |> String.replace(@_VERSION, version)
        File.write!(dest, contents)
        # Make executable
        Mix.Shell.IO.cmd "chmod +x #{dest}"
        # Return the project config after we're done
        config
    end
  end

  defp execute_release(config) do
    info "Compiling release..."
    Mix.Shell.IO.cmd  "make rel"
    config
  end

  defp do_cleanup do
    cwd = File.cwd!
    makefile = cwd |> Path.join(@_MAKEFILE)
    relfiles = cwd |> Path.join("rel")
    elixir   = cwd |> Path.join("_elixir")
    rebar    = cwd |> Path.join("rebar")
    relx     = cwd |> Path.join("relx")

    info "Removing release files..."
    if File.exists?(makefile), do: File.rm!(makefile)
    if File.exists?(relfiles), do: File.rm_rf!(relfiles)
    if File.exists?(elixir),   do: File.rm_rf!(elixir)
    if File.exists?(rebar),    do: File.rm!(rebar)
    if File.exists?(relx),     do: File.rm!(relx)
    success "All release files were removed successfully!"
  end

  defp info(message) do
    IO.puts message
  end

  defp success(message) do
    IO.puts "#{IO.ANSI.green}#{message}#{IO.ANSI.reset}"
  end

end