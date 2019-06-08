# 88888b.  8888b.
# 888 "88b    "88b
# 888  888.d888888
# 888  888888  888
# 888  888"Y888888
#
# Brett Terpstra 2017

# `na` is a bash function designed to make it easy to see what your next actions are for any project,
# right from the command line. It works with TaskPaper-format files (but any plain text format will do),
# looking for @na tags (or whatever you specify) in todo files in your current folder. It can also
# auto-display next actions when you enter a project directory, automatically locating any todo files and
# listing their next actions when you `cd` to the project (optionally recursive).
#
# na -h for help

# NA_TODO_EXT Must be set to something to limit text searches
: ${NA_TODO_EXT:="taskpaper"}
: ${NA_NEXT_TAG="@na"}
: ${NA_DONE_TAG:="@done"}
: ${NA_MAX_DEPTH:=3}
: ${NA_AUTO_LIST_FOR_DIR:=1} # 0 to disable
: ${NA_AUTO_LIST_IS_RECURSIVE:=0}

function na() {
  local DKGRAY="\033[1;30m"
  local GREEN="\033[0;32m"
  local DEFAULT="\033[0;39m"
  local CYAN="\033[0;36m"
  local YELLOW="\033[0;33m"
  IFS='' read -r -d '' helpstring <<'ENDHELPSTRING'
na [-r] [-t tag [-v value]] [query [additional identifiers]]
na -a [-n] [-t tag] 'todo text'

options:
-r        recurse 3 directories deep and concatenate all $NA_TODO_EXT files
-a [todo] add a todo to todo.$NA_TODO_EXT in the current dir
-n        with -a, prompt for a note after reading task
-t        specify an alternate tag (default @na)
          pass empty quotes to apply no automatic tag
-p [X]    add a @priority(X) tag
-v        search for tag with specific value (requires -t)
-h        show a brief help message
ENDHELPSTRING
  # _from "Installed from /Users/ttscoff/.bash_it/plugins/enabled/brett.plugin.bash"
  if [ $# -gt 0 ]; then
    if [[ $NA_AUTO_LIST_IS_RECURSIVE -eq 1 ]]; then
      na_prompt_command="na -r"
    else
      na_prompt_command="na"
    fi
    local fnd=''
    local recurse=0
    local add=0
    local note=0
    local altTag=0
    local priority=0
    local task tagValue taskTag taskNote target
    while [ "$1" ]; do
      case "$1" in
      --prompt)
        [[ $(history 1 | sed -e "s/^[ ]*[0-9]*[ ]*//") =~ ^((cd|z|j|g|f|pushd|popd|exit)([ ]|$)) ]] && $na_prompt_command
        return
        ;;
      -*)
        local opt=${1:1}
        while [ "$opt" ]; do
          case ${opt:0:1} in
          r) recurse=1 ;;
          a) add=1 ;;
          n) note=1 ;;
          p)
            if [[ $2 != '' && $2 =~ ^[0-9]+ ]]; then
              shift
              priority=$1
            else
              priority=0
            fi
            ;;
          h)
            echo $helpstring >&2
            return
            ;;
          t)
            if [[ $2 != '' && $2 =~ ^[^\-] ]]; then
              shift
              altTag="@${1#@}"
            else
              altTag=''
            fi
            ;;
          v)
            if [[ $2 != '' && $2 =~ ^[^\-] ]]; then
              shift
              [[ $1 != '' ]] && tagValue=$1
            fi
            ;;
          *)
            fnd+="$1 "
            break
            ;; # unknown option detected
          esac
          opt="${opt:1}"
        done
        ;;
      *) fnd+="$1 " ;;
      esac
      shift
    done
  fi

  if [[ $altTag == '' && $add -ne 0 ]]; then
    taskTag=''
  elif [[ $altTag != 0 && ${#altTag} -gt 0 ]]; then
    taskTag=$altTag
  else
    taskTag=$NA_NEXT_TAG
  fi

  if [[ $add -eq 1 ]]; then
    if [[ $priority -gt 0 ]]; then
      taskTag="@priority(${priority}) $taskTag"
    fi
  else
    if [[ $priority -gt 0 ]]; then
      taskTag="@priority(${priority})"
    fi
  fi

  if [[ -n $tagValue && $tagValue != '' ]]; then
    taskTag="$taskTag(${tagValue})"
  fi

  if [[ $add -eq 0 && ${#fnd} -eq 0 && $recurse -eq 0 ]]; then
    # Do an ls to see if there are any matching files
    CHKFILES=$(ls -C1 *.$NA_TODO_EXT 2>/dev/null | wc -l)
    if [[ $CHKFILES -ne 0 ]]; then
      echo -en $GREEN

      echo -e "$(grep -Eh "(^\t*-|: *@.*$)" *.$NA_TODO_EXT |
        grep -h "$taskTag" |
        grep -v "$NA_DONE_TAG" |
        awk '{gsub(/(^[ \t\-]+| '"$(echo "$taskTag" | sed -E 's/([\(\)])/\\\1/g')"')/, "")};1' |
        sed -E "s/(@[^\(]*)((\()([^\)]*)(\)))/\\$CYAN\1\3\\$YELLOW\4\\$CYAN\5\\$GREEN/g")"
      echo "$(pwd)" >>~/.tdlist
      sort -u ~/.tdlist -o ~/.tdlist
    fi
    return
  fi

  if [[ $recurse -eq 1 && ${#fnd} -eq 0 ]]; then # if the only argument is -r
    # echo -en $GREEN
    dirlist=$(find -maxdepth $NA_MAX_DEPTH . -name "*.$NA_TODO_EXT" -exec grep -H "$taskTag" {} \; | grep -v "$NA_DONE_TAG")
    _na_fix_output "$dirlist"
  elif [[ $add -eq 1 ]]; then # if the argument is -a
    [[ $fnd == '' ]] && read -p "Task: " fnd # No text given for the task, read from STDIN

    if [[ $fnd != '' ]]; then # if there is text to add as a todo item
      task=$fnd
      if [[ $note -eq 1 ]]; then
        echo "Enter a note, use ^d to end: "
        taskNote=$(cat)
      fi

      targetcount=$(ls -C1 *.$NA_TODO_EXT 2>/dev/null | wc -l | tr -d " ")
      if [[ $targetcount == "0" ]]; then
        local proj=${PWD##*/}
        local newfile="${proj}.${NA_TODO_EXT}"
        echo "Creating new todo file: $newfile"
        target="$newfile"
        if [ ! -e $target ]; then
          touch $target
          echo -e "Inbox:\n$proj:\n\tNew Features:\n\tIdeas:\n\tBugs:\nArchive:\nSearch Definitions:\n\tTop Priority @search(@priority = 5 and not @done)\n\tHigh Priority @search(@priority > 3 and not @done)\n\tMaybe @search(@maybe)\n\tNext @search(@na and not @done and not project = \"Archive\")\n" >>$target
        fi
      else
        declare -a fileList=(*\.*$NA_TODO_EXT*)
        if [[ ${#fileList[*]} == 1 ]]; then
          target=${fileList[0]}
        elif [[ ${#fileList[*]} -gt 1 ]]; then
          local counter=1
          for f in ${fileList[@]}; do
            echo "$counter) $f"
            counter=$(($counter + 1))
          done
          if [ $counter -gt 9 ]; then
            read -p "Add to which file? "
          else
            read -n1 -p "Add to which file? "
          fi
          if [[ $REPLY =~ ^[0-9]+$ ]]; then
            target=${fileList[$(($REPLY - 1))]}
          else
            return
          fi
        fi
      fi
      /usr/bin/ruby <<SCRIPT
      na = true
      task = "$task"
      note =<<'ENDNOTE'
$(echo -e $taskNote)
ENDNOTE
      input = "\t- #{task.strip}"
      if "$taskTag" != ''
        input += " $taskTag"
      end
      if note.strip.length > 0
        note = note.split(/\n/).map {|line|
          "\t\t#{line}"
        }.join("\n")
        input += "\n#{note}"
      end
      inbox_found = false
      output = ''

      if File.exists?("$target")
        File.open("$target",'r') do |f|
          while (line = f.gets)
            output += line
            unless inbox_found
              if line =~ /^\s*inbox:/i
                output += input + "\n"
                inbox_found = true
              end
            end
          end
        end
      end

      unless inbox_found
        output += "Inbox: @inbox\n"
        output += input + "\n"
      end

      todofile = File.new("$target",'w')
      todofile.puts output
      todofile.close
SCRIPT
      echo "Added to $target"
    else # no text given
      echo "Usage: na -a \"text to be added to todo.$NA_TODO_EXT inbox\""
      echo "See $(na -h) for help"
      return
    fi
  else
    _weed_cache_file
    if [[ -d "${fnd%% *}" ]]; then
      cd "${fnd%% *}" 2>/dev/null
      target="$(pwd)"
      cd - >>/dev/null
      echo "${target%/}" >>~/.tdlist
      sort -u ~/.tdlist -o ~/.tdlist
    else
      target=$(
        ruby <<SCRIPTTIME
      if (File.exists?(File.expand_path('~/.tdlist')))
        query = "$fnd"
        input = File.open(File.expand_path('~/.tdlist'),'r').read
        re = query.gsub(/\s+/,' ').split(" ").join('.*?')
        res = input.scan(/.*?#{re}.*?$/i)
        exit if res.nil? || res.empty?
        res = res.uniq.sort
        res.delete_if {|file|
          !File.exists?(File.expand_path(file))
        }
        puts res[0]
      end
SCRIPTTIME
      )
    fi
    if [[ $recurse -eq 1 ]]; then
      echo -e "$DKGRAY[$target+]:"
      dirlist=$(find -maxdepth $NA_MAX_DEPTH "$target" -name "*.$NA_TODO_EXT" -exec grep -EH "(^\t*-|: *@.*$)" {} \; | grep -v "$NA_DONE_TAG" | grep -H "$taskTag")
      _na_fix_output "$dirlist"
    else
      CHKFILES=$(ls -C1 $target/*.$NA_TODO_EXT 2>/dev/null | wc -l)
      if [ $CHKFILES -ne 0 ]; then
        echo -e "$DKGRAY[$target]:$GREEN"
        echo -e "$(grep -EH "(^\t*-|: *@.*$)" "$target"/*.$NA_TODO_EXT |
          grep -h "$taskTag" |
          grep -v "$NA_DONE_TAG" |
          awk '{gsub(/(^[ \t\-]+| '"$(echo "$taskTag" | sed -E 's/([\(\)])/\\\1/g')"')/, "")};1' |
          sed -E "s/(@[^\(]*)((\()([^\)]*)(\)))/\\$CYAN\1\3\\$YELLOW\4\\$CYAN\5\\$GREEN/g")"
      fi
    fi
  fi
  echo -en $DEFAULT
}

_na_fix_output() {
  /usr/bin/ruby <<SCRIPTTIME
    input = "$1"
    exit if input.nil? || input == ''
    olddirs = []
    if File.exists?(File.expand_path('~/.tdlist'))
      File.open(File.expand_path('~/.tdlist'),'r') do |f|
        while (line = f.gets)
          olddirs.push(line.strip) unless line =~ /^\s*$/
        end
      end
    end
    input.split("\n").each {|line|
      parts = line.scan(/([\.\/].*?\/)([^\/]+?:)(.*)$/)
      exit if parts[0].nil?
      parts = parts[0]

      dirname,filename,task = parts[0],parts[1],parts[2]
      dirparts = dirname.scan(/((\.)|(\/[^\/]+)*\/(.*))\/$/)[0]
      base = dirparts[3].nil? ? '' : dirparts[3] + "->"
      extre = "\.$NA_TODO_EXT"
      puts "$DKGRAY#{base}#{filename.gsub(/#{extre}:$/,'')} $GREEN#{task.gsub(/^[ \t\-]+/,'').gsub(/ $taskTag/,'').gsub(/(@[^\(]*)((\()([^\)]*)(\)))/,"$CYAN\\\1\\\3$YELLOW\\\4$CYAN\\\5$GREEN")}"
      olddirs.push(File.expand_path(dirname).gsub(/\/+$/,'').strip)
    }
    print "$DEFAULT"
    tdfile = File.new(File.expand_path('~/.tdlist'),'w')
    tdfile.puts olddirs.uniq.sort.join("\n")
    tdfile.close
SCRIPTTIME
}

_weed_cache_file() {
  ruby <<WEEDTIME

  # TODO: Check for git repo and do file operations in top level
    output = []
    tdlist = File.expand_path('~/.tdlist')

    if (File.exists?(tdlist))
      # If the file has been modified in the last 2 hours, leave it alone
      # if (Time.now.strftime('%s').to_i - File.stat(tdlist).mtime.strftime('%s').to_i) > 7200
        # puts "Pruning missing folders from ~/.tdlist"
        File.open(tdlist, "r") do |infile|
          infile.each_line do |line|
            output.push(line.strip) if File.exists?(File.expand_path(line.strip))
          end
        end
        open(tdlist,'w+') { |f|
          f.puts output.join("\n")
        }
      # end
    end
WEEDTIME

}

if [[ $NA_AUTO_LIST_FOR_DIR -eq 1 ]]; then
  if [[ -z "$PROMPT_COMMAND" ]]; then
    PROMPT_COMMAND="eval 'na --prompt'"
  else
    echo $PROMPT_COMMAND | grep -v -q "na --prompt" && PROMPT_COMMAND="$PROMPT_COMMAND;"'eval "na --prompt"'
  fi
fi
