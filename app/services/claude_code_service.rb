require 'open3'
require 'json'

# Run Claude Code programmatically, claude code cli for program:
# document1 https://code.claude.com/docs/en/headless
# document2 https://code.claude.com/docs/en/cli-reference

# Claude Code Service - Ruby wrapper for Claude Code CLI
# Usage:
#   service = ClaudeCodeService.new
#   result = service.ask("What is the meaning of life?")
#   result = service.ask_with_files("Explain this code", files: ["app/models/user.rb"])
class ClaudeCodeService
  attr_reader :working_directory

  def initialize(working_directory: Rails.root.to_s)
    @working_directory = working_directory
  end

  # Send a simple prompt (supports MCP skills)
  # Uses interactive mode by passing through stdin
  #
  # @param prompt [String] The question or instruction to send to Claude
  # @param skip_permissions [Boolean] Skip all permission prompts (dangerous)
  # @param permission_mode [String] Permission mode ('auto' or 'manual')
  # @param files [Array<String>] Array of file paths to include as context
  # @return [Hash] Response with :success, :output, :error, :status keys
  def ask(prompt, skip_permissions: true, permission_mode: nil, files: [])
    # If files are provided, add file references
    if files.any?
      file_references = files.map { |file_path| "@#{file_path}" }.join(" ")
      prompt = "#{file_references}\n\n#{prompt}"
    end

    execute_claude_interactive(prompt, skip_permissions: skip_permissions, permission_mode: permission_mode)
  end

  # Execute in a specific directory with file context (convenience method)
  #
  # @param prompt [String] The question or instruction to send to Claude
  # @param files [Array<String>] Array of file paths to include as context
  # @param skip_permissions [Boolean] Skip all permission prompts (dangerous)
  # @param permission_mode [String] Permission mode ('auto' or 'manual')
  # @return [Hash] Response with :success, :output, :error, :status keys
  def ask_with_files(prompt, files: [], skip_permissions: true, permission_mode: nil)
    ask(prompt, skip_permissions: skip_permissions, permission_mode: permission_mode, files: files)
  end

  private

  # Execute interactive Claude command (supports skills)
  def execute_claude_interactive(prompt, skip_permissions: false, permission_mode: nil)
    Dir.chdir(@working_directory) do
      # Build command arguments
      command = ["claude"]

      # Add permission-related arguments
      if skip_permissions
        command << "--dangerously-skip-permissions"
      elsif permission_mode
        command << "--permission-mode" << permission_mode
      end

      # Pass prompt through stdin, not using -p parameter
      stdout, stderr, status = Open3.capture3(
        *command,
        stdin_data: prompt + "\n"
      )

      if status.success?
        { success: true, output: stdout, error: nil, status: status.exitstatus }
      else
        { success: false, output: stdout, error: stderr, status: status.exitstatus }
      end
    end
  rescue Errno::ENOENT
    error_response("Claude Code CLI not found. Please ensure it is installed and in your PATH.")
  rescue => e
    error_response("Error executing Claude Code: #{e.message}")
  end

  def error_response(error_message)
    { success: false, output: nil, error: error_message, status: 1 }
  end
end
