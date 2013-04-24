#!/usr/bin/env ruby

SCRIPTS_BASE='/opt/git-hooks'

def abort(msg)
  STDERR.puts "FATAL: #{msg}"
  exit 1
end

abort("GL_USER not set") unless ENV['GL_USER']

def usage
  puts <<END

Usage:  ssh git@host hooks show <repo> <hook>        # Shows current active hooks for repo.
        ssh git@host hooks list [<hook>]             # List available hooks for a certain type. If <hook> is omitted all hooks are shown.
        ssh git@host hooks add  <repo> <hook/script> # Add a certain script to a hook - this must be named like hook/script.
        ssh git@host hooks rm   <repo> <hook/script> # Removes a certain hook script from a repository.

Only users with '+' access to a repository can show, add or rm hooks from this repository.

END
  exit 0
end

def check_access(repo,user)
  `gitolite access -q "#{repo}" #{user} + any`
  $?.to_i == 0
end



def list_hooks(hook=nil)
  hooks = hook.nil? ? allowed_hooks : [ hook ]
  hooks.each do |type|
    if !all_hooks[type].nil? && !all_hooks[type].empty?
      puts "#{type}:"
      all_hooks[type].each do |h|
        puts "  #{h}"
      end
      puts
    end
  end
end

def show_hooks(repo,hook)
  abort("Hook #{hook} is  not part of allowed types: #{allowed_hooks.join(', ')}.") unless allowed_hooks.include?(hook)
  hook_file = hook_file_path(repo,hook)
  abort("No such hookfile #{hook} exists.") unless File.exists?(hook_file)
  puts 'Current hooks:'
  puts '--------------'
  puts
  puts current_hooks(hook_file).join("\n")
end

def add_hook(repo,script)
  hook,script = script.split('/',2)
  abort("Hook (#{hook}) not part of allowed hooks: #{allowed_hooks.join(', ')}.") unless allowed_hooks.include?(hook)
  abort("Script #{script} is not part of the existing hooks.") unless all_hooks[hook].include?(script)
  script_file = script_path(script,hook)
  hook_file = hook_file_path(repo,hook)
  abort("Script is already activated for this hook.") if File.exists?(hook_file) && current_hooks(hook_file).include?(script)

  File.open(hook_file,'w') do |fh|
    fh.puts script_file
  end
  File.chmod(0700,hook_file) unless File.executable?(hook_file)
  puts "Script #{script} activated for hook #{hook}."
end

def rm_hook(repo,script)
  hook,script = script.split('/',2)
  hook_file = hook_file_path(repo,hook)
  abort("No such hook #{hook} exists.") unless File.exists?(hook_file)
  abort("No such script #{script} activated in this hook #{hook}.") unless current_hooks(hook_file).include?(script)
  File.open(hook_file,'w') do |fh|
    fh.write(current_content(hook_file).reject{|l| l.chomp == script_path(script) }.join(''))
  end
  puts "Script #{script} removed from hook #{hook},"
end

def current_hooks(hook_file)
  current_content(hook_file).collect{|l| File.basename(l.chomp) if l =~ /^#{Regexp.escape(SCRIPTS_BASE)}/ }.compact
end

def current_content(hook_file)
  File.readlines(hook_file)
end

def repo_name(repo)
  repo =~ /\.git$/ ? repo : "#{repo}.git"
end

def script_path(script,type)
  File.expand_path(File.join(SCRIPTS_BASE,type,script))
end

def repo_path(repo)
  (@repo_path ||= {})[repo] ||= File.expand_path(File.join(ENV['GL_REPO_BASE'],repo))
end

def allowed_hooks
  @allowed_hooks ||= ['pre-receive','post-receive']
end

def all_hooks
  @all_hooks ||= allowed_hooks.inject({}) do |res,type|
    res[type] = Dir[File.join(SCRIPTS_BASE,type,'*')].collect{|f| File.basename(f) }
    res
  end
end

def hook_file_path(repo,hook)
  File.join(repo_path(repo),'hooks',hook)
end

def verify_repo(repo)
  p = repo_path(repo)
  abort("Repository is not part of your REPO_BASE.") unless /^#{Regexp.escape(ENV['GL_REPO_BASE'])}/ =~ p
  abort("Repository does not exist.") unless File.directory?(p)
  p
end

cmd = ARGV.shift
case cmd
when 'list'
  list_hooks(ARGV.shift)
when 'show','add','rm'
  repo = repo_name(ARGV.shift)
  second_arg = ARGV.shift
  usage() if second_arg.nil?
  abort('You do not have sufficient permissions (requires +) on this repository.') unless check_access(repo,ENV['GL_USER'])
  verify_repo(repo)
  case cmd
  when 'show'
    show_hooks(repo, second_arg)
  when 'add'
    add_hook(repo, second_arg)
  when 'rm'
    rm_hook(repo, second_arg)
  end
else
  usage
end
