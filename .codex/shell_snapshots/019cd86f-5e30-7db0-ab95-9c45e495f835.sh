# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
+vi-git-aheadbehind () {
	local ahead behind
	local -a gitstatus
	ahead="$(git rev-list --count "${hook_com[branch]}"@{upstream}..HEAD 2>/dev/null)" 
	(( ahead )) && gitstatus+=(" $(print_icon 'VCS_OUTGOING_CHANGES_ICON')${ahead// /}") 
	behind="$(git rev-list --count HEAD.."${hook_com[branch]}"@{upstream} 2>/dev/null)" 
	(( behind )) && gitstatus+=(" $(print_icon 'VCS_INCOMING_CHANGES_ICON')${behind// /}") 
	hook_com[misc]+=${(j::)gitstatus} 
}
+vi-git-remotebranch () {
	local remote
	local branch_name="${hook_com[branch]}" 
	remote="$(git rev-parse --verify HEAD@{upstream} --symbolic-full-name 2>/dev/null)" 
	remote=${remote/refs\/(remotes|heads)\/} 
	if (( $+_POWERLEVEL9K_VCS_SHORTEN_LENGTH && $+_POWERLEVEL9K_VCS_SHORTEN_MIN_LENGTH ))
	then
		if (( ${#hook_com[branch]} > _POWERLEVEL9K_VCS_SHORTEN_MIN_LENGTH && ${#hook_com[branch]} > _POWERLEVEL9K_VCS_SHORTEN_LENGTH ))
		then
			case $_POWERLEVEL9K_VCS_SHORTEN_STRATEGY in
				(truncate_middle) hook_com[branch]="${branch_name:0:$_POWERLEVEL9K_VCS_SHORTEN_LENGTH}${_POWERLEVEL9K_VCS_SHORTEN_DELIMITER}${branch_name: -$_POWERLEVEL9K_VCS_SHORTEN_LENGTH}"  ;;
				(truncate_from_right) hook_com[branch]="${branch_name:0:$_POWERLEVEL9K_VCS_SHORTEN_LENGTH}${_POWERLEVEL9K_VCS_SHORTEN_DELIMITER}"  ;;
			esac
		fi
	fi
	if (( _POWERLEVEL9K_HIDE_BRANCH_ICON ))
	then
		hook_com[branch]="${hook_com[branch]}" 
	else
		hook_com[branch]="$(print_icon 'VCS_BRANCH_ICON')${hook_com[branch]}" 
	fi
	if [[ -n ${remote} ]] && [[ "${remote#*/}" != "${branch_name}" ]]
	then
		hook_com[branch]+="$(print_icon 'VCS_REMOTE_BRANCH_ICON')${remote// /}" 
	fi
}
+vi-git-stash () {
	if [[ -s "${vcs_comm[gitdir]}/logs/refs/stash" ]]
	then
		local -a stashes=("${(@f)"$(<${vcs_comm[gitdir]}/logs/refs/stash)"}") 
		hook_com[misc]+=" $(print_icon 'VCS_STASH_ICON')${#stashes}" 
	fi
}
+vi-git-tagname () {
	if (( !_POWERLEVEL9K_VCS_HIDE_TAGS ))
	then
		local tag
		tag="$(git describe --tags --exact-match HEAD 2>/dev/null)" 
		if [[ -n "${tag}" ]]
		then
			if [[ -z "$(git symbolic-ref HEAD 2>/dev/null)" ]]
			then
				local revision
				revision="$(git rev-list -n 1 --abbrev-commit --abbrev=${_POWERLEVEL9K_CHANGESET_HASH_LENGTH} HEAD)" 
				if (( _POWERLEVEL9K_HIDE_BRANCH_ICON ))
				then
					hook_com[branch]="${revision} $(print_icon 'VCS_TAG_ICON')${tag}" 
				else
					hook_com[branch]="$(print_icon 'VCS_BRANCH_ICON')${revision} $(print_icon 'VCS_TAG_ICON')${tag}" 
				fi
			else
				hook_com[branch]+=" $(print_icon 'VCS_TAG_ICON')${tag}" 
			fi
		fi
	fi
}
+vi-git-untracked () {
	[[ -z "${vcs_comm[gitdir]}" || "${vcs_comm[gitdir]}" == "." ]] && return
	local repoTopLevel="$(git rev-parse --show-toplevel 2> /dev/null)" 
	[[ $? != 0 || -z $repoTopLevel ]] && return
	local untrackedFiles="$(git ls-files --others --exclude-standard "${repoTopLevel}" 2> /dev/null)" 
	if [[ -z $untrackedFiles && $_POWERLEVEL9K_VCS_SHOW_SUBMODULE_DIRTY == 1 ]]
	then
		untrackedFiles+="$(git submodule foreach --quiet --recursive 'git ls-files --others --exclude-standard' 2> /dev/null)" 
	fi
	[[ -z $untrackedFiles ]] && return
	hook_com[unstaged]+=" $(print_icon 'VCS_UNTRACKED_ICON')" 
	VCS_WORKDIR_HALF_DIRTY=true 
}
+vi-hg-bookmarks () {
	if [[ -n "${hgbmarks[@]}" ]]
	then
		hook_com[hg-bookmark-string]=" $(print_icon 'VCS_BOOKMARK_ICON')${hgbmarks[@]}" 
		ret=1 
		return 0
	fi
}
+vi-svn-detect-changes () {
	local svn_status="$(svn status)" 
	if [[ -n "$(echo "$svn_status" | \grep \^\?)" ]]
	then
		hook_com[unstaged]+=" $(print_icon 'VCS_UNTRACKED_ICON')" 
		VCS_WORKDIR_HALF_DIRTY=true 
	fi
	if [[ -n "$(echo "$svn_status" | \grep \^\M)" ]]
	then
		hook_com[unstaged]+=" $(print_icon 'VCS_UNSTAGED_ICON')" 
		VCS_WORKDIR_DIRTY=true 
	fi
	if [[ -n "$(echo "$svn_status" | \grep \^\A)" ]]
	then
		hook_com[staged]+=" $(print_icon 'VCS_STAGED_ICON')" 
		VCS_WORKDIR_DIRTY=true 
	fi
}
+vi-vcs-detect-changes () {
	if [[ "${hook_com[vcs]}" == "git" ]]
	then
		local remote="$(git ls-remote --get-url 2> /dev/null)" 
		_p9k_vcs_icon "$remote"
		vcs_visual_identifier=$_p9k__ret 
	elif [[ "${hook_com[vcs]}" == "hg" ]]
	then
		vcs_visual_identifier='VCS_HG_ICON' 
	elif [[ "${hook_com[vcs]}" == "svn" ]]
	then
		vcs_visual_identifier='VCS_SVN_ICON' 
	fi
	if [[ -n "${hook_com[staged]}" ]] || [[ -n "${hook_com[unstaged]}" ]]
	then
		VCS_WORKDIR_DIRTY=true 
	else
		VCS_WORKDIR_DIRTY=false 
	fi
}
VCS_INFO_formats () {
	setopt localoptions noksharrays NO_shwordsplit
	local msg tmp
	local -i i
	local -A hook_com
	hook_com=(action "$1" action_orig "$1" branch "$2" branch_orig "$2" base "$3" base_orig "$3" staged "$4" staged_orig "$4" unstaged "$5" unstaged_orig "$5" revision "$6" revision_orig "$6" misc "$7" misc_orig "$7" vcs "${vcs}" vcs_orig "${vcs}") 
	hook_com[base-name]="${${hook_com[base]}:t}" 
	hook_com[base-name_orig]="${hook_com[base-name]}" 
	hook_com[subdir]="$(VCS_INFO_reposub ${hook_com[base]})" 
	hook_com[subdir_orig]="${hook_com[subdir]}" 
	: vcs_info-patch-9b9840f2-91e5-4471-af84-9e9a0dc68c1b
	for tmp in base base-name branch misc revision subdir
	do
		hook_com[$tmp]="${hook_com[$tmp]//\%/%%}" 
	done
	VCS_INFO_hook 'post-backend'
	if [[ -n ${hook_com[action]} ]]
	then
		zstyle -a ":vcs_info:${vcs}:${usercontext}:${rrn}" actionformats msgs
		(( ${#msgs} < 1 )) && msgs[1]=' (%s)-[%b|%a]%u%c-' 
	else
		zstyle -a ":vcs_info:${vcs}:${usercontext}:${rrn}" formats msgs
		(( ${#msgs} < 1 )) && msgs[1]=' (%s)-[%b]%u%c-' 
	fi
	if [[ -n ${hook_com[staged]} ]]
	then
		zstyle -s ":vcs_info:${vcs}:${usercontext}:${rrn}" stagedstr tmp
		[[ -z ${tmp} ]] && hook_com[staged]='S'  || hook_com[staged]=${tmp} 
	fi
	if [[ -n ${hook_com[unstaged]} ]]
	then
		zstyle -s ":vcs_info:${vcs}:${usercontext}:${rrn}" unstagedstr tmp
		[[ -z ${tmp} ]] && hook_com[unstaged]='U'  || hook_com[unstaged]=${tmp} 
	fi
	if [[ ${quiltmode} != 'standalone' ]] && VCS_INFO_hook "pre-addon-quilt"
	then
		local REPLY
		VCS_INFO_quilt addon
		hook_com[quilt]="${REPLY}" 
		unset REPLY
	elif [[ ${quiltmode} == 'standalone' ]]
	then
		hook_com[quilt]=${hook_com[misc]} 
	fi
	(( ${#msgs} > maxexports )) && msgs[$(( maxexports + 1 )),-1]=() 
	for i in {1..${#msgs}}
	do
		if VCS_INFO_hook "set-message" $(( $i - 1 )) "${msgs[$i]}"
		then
			zformat -f msg ${msgs[$i]} a:${hook_com[action]} b:${hook_com[branch]} c:${hook_com[staged]} i:${hook_com[revision]} m:${hook_com[misc]} r:${hook_com[base-name]} s:${hook_com[vcs]} u:${hook_com[unstaged]} Q:${hook_com[quilt]} R:${hook_com[base]} S:${hook_com[subdir]}
			msgs[$i]=${msg} 
		else
			msgs[$i]=${hook_com[message]} 
		fi
	done
	hook_com=() 
	backend_misc=() 
	return 0
}
_SUSEconfig () {
	# undefined
	builtin autoload -XUz
}
__arguments () {
	# undefined
	builtin autoload -XUz
}
__git_prompt_git () {
	GIT_OPTIONAL_LOCKS=0 command git "$@"
}
__starship_get_time () {
	(( STARSHIP_CAPTURED_TIME = int(rint(EPOCHREALTIME * 1000)) ))
}
_a2ps () {
	# undefined
	builtin autoload -XUz
}
_a2utils () {
	# undefined
	builtin autoload -XUz
}
_aap () {
	# undefined
	builtin autoload -XUz
}
_abcde () {
	# undefined
	builtin autoload -XUz
}
_absolute_command_paths () {
	# undefined
	builtin autoload -XUz
}
_ack () {
	# undefined
	builtin autoload -XUz
}
_acpi () {
	# undefined
	builtin autoload -XUz
}
_acpitool () {
	# undefined
	builtin autoload -XUz
}
_acroread () {
	# undefined
	builtin autoload -XUz
}
_adb () {
	# undefined
	builtin autoload -XUz
}
_add-zle-hook-widget () {
	# undefined
	builtin autoload -XUz
}
_add-zsh-hook () {
	# undefined
	builtin autoload -XUz
}
_alias () {
	# undefined
	builtin autoload -XUz
}
_aliases () {
	# undefined
	builtin autoload -XUz
}
_all_labels () {
	# undefined
	builtin autoload -XUz
}
_all_matches () {
	# undefined
	builtin autoload -XUz
}
_alsa-utils () {
	# undefined
	builtin autoload -XUz
}
_alternative () {
	# undefined
	builtin autoload -XUz
}
_analyseplugin () {
	# undefined
	builtin autoload -XUz
}
_ansible () {
	# undefined
	builtin autoload -XUz
}
_ant () {
	# undefined
	builtin autoload -XUz
}
_antiword () {
	# undefined
	builtin autoload -XUz
}
_apachectl () {
	# undefined
	builtin autoload -XUz
}
_apm () {
	# undefined
	builtin autoload -XUz
}
_approximate () {
	# undefined
	builtin autoload -XUz
}
_apt () {
	# undefined
	builtin autoload -XUz
}
_apt-file () {
	# undefined
	builtin autoload -XUz
}
_apt-move () {
	# undefined
	builtin autoload -XUz
}
_apt-show-versions () {
	# undefined
	builtin autoload -XUz
}
_aptitude () {
	# undefined
	builtin autoload -XUz
}
_arch_archives () {
	# undefined
	builtin autoload -XUz
}
_arch_namespace () {
	# undefined
	builtin autoload -XUz
}
_arg_compile () {
	# undefined
	builtin autoload -XUz
}
_arguments () {
	# undefined
	builtin autoload -XUz
}
_arp () {
	# undefined
	builtin autoload -XUz
}
_arping () {
	# undefined
	builtin autoload -XUz
}
_arrays () {
	# undefined
	builtin autoload -XUz
}
_asciidoctor () {
	# undefined
	builtin autoload -XUz
}
_asciinema () {
	# undefined
	builtin autoload -XUz
}
_assign () {
	# undefined
	builtin autoload -XUz
}
_at () {
	# undefined
	builtin autoload -XUz
}
_attr () {
	# undefined
	builtin autoload -XUz
}
_augeas () {
	# undefined
	builtin autoload -XUz
}
_auto-apt () {
	# undefined
	builtin autoload -XUz
}
_autocd () {
	# undefined
	builtin autoload -XUz
}
_avahi () {
	# undefined
	builtin autoload -XUz
}
_awk () {
	# undefined
	builtin autoload -XUz
}
_axi-cache () {
	# undefined
	builtin autoload -XUz
}
_base64 () {
	# undefined
	builtin autoload -XUz
}
_basename () {
	# undefined
	builtin autoload -XUz
}
_basenc () {
	# undefined
	builtin autoload -XUz
}
_bash () {
	# undefined
	builtin autoload -XUz
}
_bash_complete () {
	local ret=1 
	local -a suf matches
	local -x COMP_POINT COMP_CWORD
	local -a COMP_WORDS COMPREPLY BASH_VERSINFO
	local -x COMP_LINE="$words" 
	local -A savejobstates savejobtexts
	(( COMP_POINT = 1 + ${#${(j. .)words[1,CURRENT-1]}} + $#QIPREFIX + $#IPREFIX + $#PREFIX ))
	(( COMP_CWORD = CURRENT - 1))
	COMP_WORDS=("${words[@]}") 
	BASH_VERSINFO=(2 05b 0 1 release) 
	savejobstates=(${(kv)jobstates}) 
	savejobtexts=(${(kv)jobtexts}) 
	[[ ${argv[${argv[(I)nospace]:-0}-1]} = -o ]] && suf=(-S '') 
	matches=(${(f)"$(compgen $@ -- ${words[CURRENT]})"}) 
	if [[ -n $matches ]]
	then
		if [[ ${argv[${argv[(I)filenames]:-0}-1]} = -o ]]
		then
			compset -P '*/' && matches=(${matches##*/}) 
			compset -S '/*' && matches=(${matches%%/*}) 
			compadd -f "${suf[@]}" -a matches && ret=0 
		else
			compadd "${suf[@]}" - "${(@)${(Q@)matches}:#*\ }" && ret=0 
			compadd -S ' ' - ${${(M)${(Q)matches}:#*\ }% } && ret=0 
		fi
	fi
	if (( ret ))
	then
		if [[ ${argv[${argv[(I)default]:-0}-1]} = -o ]]
		then
			_default "${suf[@]}" && ret=0 
		elif [[ ${argv[${argv[(I)dirnames]:-0}-1]} = -o ]]
		then
			_directories "${suf[@]}" && ret=0 
		fi
	fi
	return ret
}
_bash_completions () {
	# undefined
	builtin autoload -XUz
}
_baudrates () {
	# undefined
	builtin autoload -XUz
}
_baz () {
	# undefined
	builtin autoload -XUz
}
_be_name () {
	# undefined
	builtin autoload -XUz
}
_beadm () {
	# undefined
	builtin autoload -XUz
}
_beep () {
	# undefined
	builtin autoload -XUz
}
_bibtex () {
	# undefined
	builtin autoload -XUz
}
_bind_addresses () {
	# undefined
	builtin autoload -XUz
}
_bindkey () {
	# undefined
	builtin autoload -XUz
}
_bison () {
	# undefined
	builtin autoload -XUz
}
_bittorrent () {
	# undefined
	builtin autoload -XUz
}
_bluetoothctl () {
	# undefined
	builtin autoload -XUz
}
_bogofilter () {
	# undefined
	builtin autoload -XUz
}
_bootctl () {
	# undefined
	builtin autoload -XUz
}
_bpf_filters () {
	# undefined
	builtin autoload -XUz
}
_bpython () {
	# undefined
	builtin autoload -XUz
}
_brace_parameter () {
	# undefined
	builtin autoload -XUz
}
_brctl () {
	# undefined
	builtin autoload -XUz
}
_bsd_disks () {
	# undefined
	builtin autoload -XUz
}
_bsd_pkg () {
	# undefined
	builtin autoload -XUz
}
_bsdconfig () {
	# undefined
	builtin autoload -XUz
}
_bsdinstall () {
	# undefined
	builtin autoload -XUz
}
_btrfs () {
	# undefined
	builtin autoload -XUz
}
_bts () {
	# undefined
	builtin autoload -XUz
}
_bug () {
	# undefined
	builtin autoload -XUz
}
_builtin () {
	# undefined
	builtin autoload -XUz
}
_busctl () {
	# undefined
	builtin autoload -XUz
}
_bzip2 () {
	# undefined
	builtin autoload -XUz
}
_bzr () {
	# undefined
	builtin autoload -XUz
}
_cabal () {
	# undefined
	builtin autoload -XUz
}
_cache_invalid () {
	# undefined
	builtin autoload -XUz
}
_caffeinate () {
	# undefined
	builtin autoload -XUz
}
_cal () {
	# undefined
	builtin autoload -XUz
}
_calendar () {
	# undefined
	builtin autoload -XUz
}
_call_function () {
	# undefined
	builtin autoload -XUz
}
_call_program () {
	local -xi COLUMNS=999 
	local curcontext="${curcontext}" tmp err_fd=-1 clocale='_comp_locale;' 
	local -a prefix
	if [[ "$1" = -p ]]
	then
		shift
		if (( $#_comp_priv_prefix ))
		then
			curcontext="${curcontext%:*}/${${(@M)_comp_priv_prefix:#^*[^\\]=*}[1]}:" 
			zstyle -t ":completion:${curcontext}:${1}" gain-privileges && prefix=($_comp_priv_prefix) 
		fi
	elif [[ "$1" = -l ]]
	then
		shift
		clocale='' 
	fi
	if (( ${debug_fd:--1} > 2 )) || [[ ! -t 2 ]]
	then
		exec {err_fd}>&2
	else
		exec {err_fd}> /dev/null
	fi
	{
		if zstyle -s ":completion:${curcontext}:${1}" command tmp
		then
			if [[ "$tmp" = -* ]]
			then
				eval $clocale "$tmp[2,-1]" "$argv[2,-1]"
			else
				eval $clocale $prefix "$tmp"
			fi
		else
			eval $clocale $prefix "$argv[2,-1]"
		fi 2>&$err_fd
	} always {
		exec {err_fd}>&-
	}
}
_canonical_paths () {
	# undefined
	builtin autoload -XUz
}
_capabilities () {
	# undefined
	builtin autoload -XUz
}
_cat () {
	# undefined
	builtin autoload -XUz
}
_ccal () {
	# undefined
	builtin autoload -XUz
}
_cd () {
	# undefined
	builtin autoload -XUz
}
_cdbs-edit-patch () {
	# undefined
	builtin autoload -XUz
}
_cdcd () {
	# undefined
	builtin autoload -XUz
}
_cdr () {
	# undefined
	builtin autoload -XUz
}
_cdrdao () {
	# undefined
	builtin autoload -XUz
}
_cdrecord () {
	# undefined
	builtin autoload -XUz
}
_chattr () {
	# undefined
	builtin autoload -XUz
}
_chcon () {
	# undefined
	builtin autoload -XUz
}
_chflags () {
	# undefined
	builtin autoload -XUz
}
_chkconfig () {
	# undefined
	builtin autoload -XUz
}
_chmod () {
	# undefined
	builtin autoload -XUz
}
_choom () {
	# undefined
	builtin autoload -XUz
}
_chown () {
	# undefined
	builtin autoload -XUz
}
_chroot () {
	# undefined
	builtin autoload -XUz
}
_chrt () {
	# undefined
	builtin autoload -XUz
}
_chsh () {
	# undefined
	builtin autoload -XUz
}
_cksum () {
	# undefined
	builtin autoload -XUz
}
_clay () {
	# undefined
	builtin autoload -XUz
}
_cmdambivalent () {
	# undefined
	builtin autoload -XUz
}
_cmdstring () {
	# undefined
	builtin autoload -XUz
}
_cmp () {
	# undefined
	builtin autoload -XUz
}
_code () {
	# undefined
	builtin autoload -XUz
}
_codex () {
	# undefined
	builtin autoload -XUz
}
_column () {
	# undefined
	builtin autoload -XUz
}
_combination () {
	# undefined
	builtin autoload -XUz
}
_comm () {
	# undefined
	builtin autoload -XUz
}
_command () {
	# undefined
	builtin autoload -XUz
}
_command_names () {
	# undefined
	builtin autoload -XUz
}
_comp_locale () {
	# undefined
	builtin autoload -XUz
}
_compadd () {
	# undefined
	builtin autoload -XUz
}
_compdef () {
	# undefined
	builtin autoload -XUz
}
_complete () {
	# undefined
	builtin autoload -XUz
}
_complete_debug () {
	# undefined
	builtin autoload -XUz
}
_complete_help () {
	# undefined
	builtin autoload -XUz
}
_complete_help_generic () {
	# undefined
	builtin autoload -XUz
}
_complete_tag () {
	# undefined
	builtin autoload -XUz
}
_completers () {
	# undefined
	builtin autoload -XUz
}
_composer () {
	# undefined
	builtin autoload -XUz
}
_compress () {
	# undefined
	builtin autoload -XUz
}
_condition () {
	# undefined
	builtin autoload -XUz
}
_configure () {
	# undefined
	builtin autoload -XUz
}
_coreadm () {
	# undefined
	builtin autoload -XUz
}
_coredumpctl () {
	# undefined
	builtin autoload -XUz
}
_correct () {
	# undefined
	builtin autoload -XUz
}
_correct_filename () {
	# undefined
	builtin autoload -XUz
}
_correct_word () {
	# undefined
	builtin autoload -XUz
}
_cowsay () {
	# undefined
	builtin autoload -XUz
}
_cp () {
	# undefined
	builtin autoload -XUz
}
_cpio () {
	# undefined
	builtin autoload -XUz
}
_cplay () {
	# undefined
	builtin autoload -XUz
}
_cpupower () {
	# undefined
	builtin autoload -XUz
}
_crontab () {
	# undefined
	builtin autoload -XUz
}
_cryptsetup () {
	# undefined
	builtin autoload -XUz
}
_cscope () {
	# undefined
	builtin autoload -XUz
}
_csplit () {
	# undefined
	builtin autoload -XUz
}
_cssh () {
	# undefined
	builtin autoload -XUz
}
_csup () {
	# undefined
	builtin autoload -XUz
}
_ctags () {
	# undefined
	builtin autoload -XUz
}
_ctags_tags () {
	# undefined
	builtin autoload -XUz
}
_cu () {
	# undefined
	builtin autoload -XUz
}
_curl () {
	# undefined
	builtin autoload -XUz
}
_cut () {
	# undefined
	builtin autoload -XUz
}
_cvs () {
	# undefined
	builtin autoload -XUz
}
_cvsup () {
	# undefined
	builtin autoload -XUz
}
_cygcheck () {
	# undefined
	builtin autoload -XUz
}
_cygpath () {
	# undefined
	builtin autoload -XUz
}
_cygrunsrv () {
	# undefined
	builtin autoload -XUz
}
_cygserver () {
	# undefined
	builtin autoload -XUz
}
_cygstart () {
	# undefined
	builtin autoload -XUz
}
_dak () {
	# undefined
	builtin autoload -XUz
}
_darcs () {
	# undefined
	builtin autoload -XUz
}
_date () {
	# undefined
	builtin autoload -XUz
}
_date_formats () {
	# undefined
	builtin autoload -XUz
}
_dates () {
	# undefined
	builtin autoload -XUz
}
_dbus () {
	# undefined
	builtin autoload -XUz
}
_dchroot () {
	# undefined
	builtin autoload -XUz
}
_dchroot-dsa () {
	# undefined
	builtin autoload -XUz
}
_dconf () {
	# undefined
	builtin autoload -XUz
}
_dcop () {
	# undefined
	builtin autoload -XUz
}
_dcut () {
	# undefined
	builtin autoload -XUz
}
_dd () {
	# undefined
	builtin autoload -XUz
}
_deb_architectures () {
	# undefined
	builtin autoload -XUz
}
_deb_codenames () {
	# undefined
	builtin autoload -XUz
}
_deb_files () {
	# undefined
	builtin autoload -XUz
}
_deb_packages () {
	# undefined
	builtin autoload -XUz
}
_debbugs_bugnumber () {
	# undefined
	builtin autoload -XUz
}
_debchange () {
	# undefined
	builtin autoload -XUz
}
_debcheckout () {
	# undefined
	builtin autoload -XUz
}
_debdiff () {
	# undefined
	builtin autoload -XUz
}
_debfoster () {
	# undefined
	builtin autoload -XUz
}
_deborphan () {
	# undefined
	builtin autoload -XUz
}
_debsign () {
	# undefined
	builtin autoload -XUz
}
_debsnap () {
	# undefined
	builtin autoload -XUz
}
_debuild () {
	# undefined
	builtin autoload -XUz
}
_default () {
	# undefined
	builtin autoload -XUz
}
_defaults () {
	# undefined
	builtin autoload -XUz
}
_defer_async_git_register () {
	case "${PS1}:${PS2}:${PS3}:${PS4}:${RPROMPT}:${RPS1}:${RPS2}:${RPS3}:${RPS4}" in
		(*(\$\(git_prompt_info\)|\`git_prompt_info\`)*) _omz_register_handler _omz_git_prompt_info ;;
	esac
	case "${PS1}:${PS2}:${PS3}:${PS4}:${RPROMPT}:${RPS1}:${RPS2}:${RPS3}:${RPS4}" in
		(*(\$\(git_prompt_status\)|\`git_prompt_status\`)*) _omz_register_handler _omz_git_prompt_status ;;
	esac
	add-zsh-hook -d precmd _defer_async_git_register
	unset -f _defer_async_git_register
}
_delimiters () {
	# undefined
	builtin autoload -XUz
}
_describe () {
	# undefined
	builtin autoload -XUz
}
_description () {
	# undefined
	builtin autoload -XUz
}
_devtodo () {
	# undefined
	builtin autoload -XUz
}
_df () {
	# undefined
	builtin autoload -XUz
}
_dhclient () {
	# undefined
	builtin autoload -XUz
}
_dhcpinfo () {
	# undefined
	builtin autoload -XUz
}
_dict () {
	# undefined
	builtin autoload -XUz
}
_dict_words () {
	# undefined
	builtin autoload -XUz
}
_diff () {
	# undefined
	builtin autoload -XUz
}
_diff3 () {
	# undefined
	builtin autoload -XUz
}
_diff_options () {
	# undefined
	builtin autoload -XUz
}
_diffstat () {
	# undefined
	builtin autoload -XUz
}
_dig () {
	# undefined
	builtin autoload -XUz
}
_dir_list () {
	# undefined
	builtin autoload -XUz
}
_directories () {
	# undefined
	builtin autoload -XUz
}
_directory_stack () {
	# undefined
	builtin autoload -XUz
}
_direnv_hook () {
	trap -- '' SIGINT
	eval "$("/nix/store/facg208fw2bgsg7w0f13k5iwkp8lnsi4-direnv-2.37.1/bin/direnv" export zsh)"
	trap - SIGINT
}
_dirs () {
	# undefined
	builtin autoload -XUz
}
_disable () {
	# undefined
	builtin autoload -XUz
}
_dispatch () {
	# undefined
	builtin autoload -XUz
}
_django () {
	# undefined
	builtin autoload -XUz
}
_dkms () {
	# undefined
	builtin autoload -XUz
}
_dladm () {
	# undefined
	builtin autoload -XUz
}
_dlocate () {
	# undefined
	builtin autoload -XUz
}
_dmesg () {
	# undefined
	builtin autoload -XUz
}
_dmidecode () {
	# undefined
	builtin autoload -XUz
}
_dnf () {
	# undefined
	builtin autoload -XUz
}
_dns_types () {
	# undefined
	builtin autoload -XUz
}
_doas () {
	# undefined
	builtin autoload -XUz
}
_docker () {
	# undefined
	builtin autoload -XUz
}
_domains () {
	# undefined
	builtin autoload -XUz
}
_dos2unix () {
	# undefined
	builtin autoload -XUz
}
_dpatch-edit-patch () {
	# undefined
	builtin autoload -XUz
}
_dpkg () {
	# undefined
	builtin autoload -XUz
}
_dpkg-buildpackage () {
	# undefined
	builtin autoload -XUz
}
_dpkg-cross () {
	# undefined
	builtin autoload -XUz
}
_dpkg-repack () {
	# undefined
	builtin autoload -XUz
}
_dpkg_source () {
	# undefined
	builtin autoload -XUz
}
_dput () {
	# undefined
	builtin autoload -XUz
}
_drill () {
	# undefined
	builtin autoload -XUz
}
_dropbox () {
	# undefined
	builtin autoload -XUz
}
_dscverify () {
	# undefined
	builtin autoload -XUz
}
_dsh () {
	# undefined
	builtin autoload -XUz
}
_dtrace () {
	# undefined
	builtin autoload -XUz
}
_dtruss () {
	# undefined
	builtin autoload -XUz
}
_du () {
	# undefined
	builtin autoload -XUz
}
_dumpadm () {
	# undefined
	builtin autoload -XUz
}
_dumper () {
	# undefined
	builtin autoload -XUz
}
_dupload () {
	# undefined
	builtin autoload -XUz
}
_dvi () {
	# undefined
	builtin autoload -XUz
}
_dynamic_directory_name () {
	# undefined
	builtin autoload -XUz
}
_e2label () {
	# undefined
	builtin autoload -XUz
}
_ecasound () {
	# undefined
	builtin autoload -XUz
}
_echotc () {
	# undefined
	builtin autoload -XUz
}
_echoti () {
	# undefined
	builtin autoload -XUz
}
_ed () {
	# undefined
	builtin autoload -XUz
}
_elfdump () {
	# undefined
	builtin autoload -XUz
}
_elinks () {
	# undefined
	builtin autoload -XUz
}
_email_addresses () {
	# undefined
	builtin autoload -XUz
}
_emulate () {
	# undefined
	builtin autoload -XUz
}
_enable () {
	# undefined
	builtin autoload -XUz
}
_enscript () {
	# undefined
	builtin autoload -XUz
}
_entr () {
	# undefined
	builtin autoload -XUz
}
_env () {
	# undefined
	builtin autoload -XUz
}
_eog () {
	# undefined
	builtin autoload -XUz
}
_equal () {
	# undefined
	builtin autoload -XUz
}
_espeak () {
	# undefined
	builtin autoload -XUz
}
_etags () {
	# undefined
	builtin autoload -XUz
}
_ethtool () {
	# undefined
	builtin autoload -XUz
}
_evince () {
	# undefined
	builtin autoload -XUz
}
_exec () {
	# undefined
	builtin autoload -XUz
}
_expand () {
	# undefined
	builtin autoload -XUz
}
_expand_alias () {
	# undefined
	builtin autoload -XUz
}
_expand_word () {
	# undefined
	builtin autoload -XUz
}
_extensions () {
	# undefined
	builtin autoload -XUz
}
_external_pwds () {
	# undefined
	builtin autoload -XUz
}
_fakeroot () {
	# undefined
	builtin autoload -XUz
}
_fbsd_architectures () {
	# undefined
	builtin autoload -XUz
}
_fbsd_device_types () {
	# undefined
	builtin autoload -XUz
}
_fc () {
	# undefined
	builtin autoload -XUz
}
_fd () {
	# undefined
	builtin autoload -XUz
}
_feh () {
	# undefined
	builtin autoload -XUz
}
_fetch () {
	# undefined
	builtin autoload -XUz
}
_fetchmail () {
	# undefined
	builtin autoload -XUz
}
_ffmpeg () {
	# undefined
	builtin autoload -XUz
}
_figlet () {
	# undefined
	builtin autoload -XUz
}
_file_descriptors () {
	# undefined
	builtin autoload -XUz
}
_file_flags () {
	# undefined
	builtin autoload -XUz
}
_file_modes () {
	# undefined
	builtin autoload -XUz
}
_file_systems () {
	# undefined
	builtin autoload -XUz
}
_files () {
	# undefined
	builtin autoload -XUz
}
_find () {
	# undefined
	builtin autoload -XUz
}
_find_net_interfaces () {
	# undefined
	builtin autoload -XUz
}
_findmnt () {
	# undefined
	builtin autoload -XUz
}
_finger () {
	# undefined
	builtin autoload -XUz
}
_fink () {
	# undefined
	builtin autoload -XUz
}
_first () {
	# undefined
	builtin autoload -XUz
}
_flac () {
	# undefined
	builtin autoload -XUz
}
_flex () {
	# undefined
	builtin autoload -XUz
}
_floppy () {
	# undefined
	builtin autoload -XUz
}
_flowadm () {
	# undefined
	builtin autoload -XUz
}
_fmadm () {
	# undefined
	builtin autoload -XUz
}
_fmt () {
	# undefined
	builtin autoload -XUz
}
_fold () {
	# undefined
	builtin autoload -XUz
}
_fortune () {
	# undefined
	builtin autoload -XUz
}
_free () {
	# undefined
	builtin autoload -XUz
}
_freebsd-update () {
	# undefined
	builtin autoload -XUz
}
_fs_usage () {
	# undefined
	builtin autoload -XUz
}
_fsh () {
	# undefined
	builtin autoload -XUz
}
_fstat () {
	# undefined
	builtin autoload -XUz
}
_functions () {
	# undefined
	builtin autoload -XUz
}
_fuse_arguments () {
	# undefined
	builtin autoload -XUz
}
_fuse_values () {
	# undefined
	builtin autoload -XUz
}
_fuser () {
	# undefined
	builtin autoload -XUz
}
_fusermount () {
	# undefined
	builtin autoload -XUz
}
_fw_update () {
	# undefined
	builtin autoload -XUz
}
_gcc () {
	# undefined
	builtin autoload -XUz
}
_gcore () {
	# undefined
	builtin autoload -XUz
}
_gdb () {
	# undefined
	builtin autoload -XUz
}
_geany () {
	# undefined
	builtin autoload -XUz
}
_gem () {
	# undefined
	builtin autoload -XUz
}
_generic () {
	# undefined
	builtin autoload -XUz
}
_genisoimage () {
	# undefined
	builtin autoload -XUz
}
_getclip () {
	# undefined
	builtin autoload -XUz
}
_getconf () {
	# undefined
	builtin autoload -XUz
}
_getent () {
	# undefined
	builtin autoload -XUz
}
_getfacl () {
	# undefined
	builtin autoload -XUz
}
_getmail () {
	# undefined
	builtin autoload -XUz
}
_getopt () {
	# undefined
	builtin autoload -XUz
}
_gh () {
	# undefined
	builtin autoload -XUz
}
_ghostscript () {
	# undefined
	builtin autoload -XUz
}
_gi_curl () {
	curl -sfL "https://www.gitignore.io/api/$1"
}
_git () {
	# undefined
	builtin autoload -XUz
}
_git-buildpackage () {
	# undefined
	builtin autoload -XUz
}
_git_log_prettily () {
	if ! [ -z $1 ]
	then
		git log --pretty=$1
	fi
}
_gitignoreio () {
	compset -P '*,'
	compadd -S '' $(_gitignoreio_get_command_list)
}
_gitignoreio_get_command_list () {
	_gi_curl "list" | tr "," "\n"
}
_global () {
	# undefined
	builtin autoload -XUz
}
_global_tags () {
	# undefined
	builtin autoload -XUz
}
_globflags () {
	# undefined
	builtin autoload -XUz
}
_globqual_delims () {
	# undefined
	builtin autoload -XUz
}
_globquals () {
	# undefined
	builtin autoload -XUz
}
_gnome-gv () {
	# undefined
	builtin autoload -XUz
}
_gnu_generic () {
	# undefined
	builtin autoload -XUz
}
_gnupod () {
	# undefined
	builtin autoload -XUz
}
_gnutls () {
	# undefined
	builtin autoload -XUz
}
_go () {
	# undefined
	builtin autoload -XUz
}
_gpasswd () {
	# undefined
	builtin autoload -XUz
}
_gpg () {
	# undefined
	builtin autoload -XUz
}
_gphoto2 () {
	# undefined
	builtin autoload -XUz
}
_gprof () {
	# undefined
	builtin autoload -XUz
}
_gqview () {
	# undefined
	builtin autoload -XUz
}
_gradle () {
	# undefined
	builtin autoload -XUz
}
_graphicsmagick () {
	# undefined
	builtin autoload -XUz
}
_grep () {
	# undefined
	builtin autoload -XUz
}
_grep-excuses () {
	# undefined
	builtin autoload -XUz
}
_groff () {
	# undefined
	builtin autoload -XUz
}
_groups () {
	# undefined
	builtin autoload -XUz
}
_growisofs () {
	# undefined
	builtin autoload -XUz
}
_gsettings () {
	# undefined
	builtin autoload -XUz
}
_gstat () {
	# undefined
	builtin autoload -XUz
}
_guard () {
	# undefined
	builtin autoload -XUz
}
_guilt () {
	# undefined
	builtin autoload -XUz
}
_gv () {
	# undefined
	builtin autoload -XUz
}
_gzip () {
	# undefined
	builtin autoload -XUz
}
_hash () {
	# undefined
	builtin autoload -XUz
}
_have_glob_qual () {
	# undefined
	builtin autoload -XUz
}
_hdiutil () {
	# undefined
	builtin autoload -XUz
}
_head () {
	# undefined
	builtin autoload -XUz
}
_hexdump () {
	# undefined
	builtin autoload -XUz
}
_history () {
	# undefined
	builtin autoload -XUz
}
_history_complete_word () {
	# undefined
	builtin autoload -XUz
}
_history_modifiers () {
	# undefined
	builtin autoload -XUz
}
_host () {
	# undefined
	builtin autoload -XUz
}
_hostname () {
	# undefined
	builtin autoload -XUz
}
_hostnamectl () {
	# undefined
	builtin autoload -XUz
}
_hosts () {
	# undefined
	builtin autoload -XUz
}
_htop () {
	# undefined
	builtin autoload -XUz
}
_hwinfo () {
	# undefined
	builtin autoload -XUz
}
_hyprctl () {
	# undefined
	builtin autoload -XUz
}
_iconv () {
	# undefined
	builtin autoload -XUz
}
_iconvconfig () {
	# undefined
	builtin autoload -XUz
}
_id () {
	# undefined
	builtin autoload -XUz
}
_ifconfig () {
	# undefined
	builtin autoload -XUz
}
_iftop () {
	# undefined
	builtin autoload -XUz
}
_ignored () {
	# undefined
	builtin autoload -XUz
}
_imagemagick () {
	# undefined
	builtin autoload -XUz
}
_in_vared () {
	# undefined
	builtin autoload -XUz
}
_inetadm () {
	# undefined
	builtin autoload -XUz
}
_init_d () {
	# undefined
	builtin autoload -XUz
}
_initctl () {
	# undefined
	builtin autoload -XUz
}
_install () {
	# undefined
	builtin autoload -XUz
}
_invoke-rc.d () {
	# undefined
	builtin autoload -XUz
}
_ionice () {
	# undefined
	builtin autoload -XUz
}
_iostat () {
	# undefined
	builtin autoload -XUz
}
_ip () {
	# undefined
	builtin autoload -XUz
}
_ipadm () {
	# undefined
	builtin autoload -XUz
}
_ipfw () {
	# undefined
	builtin autoload -XUz
}
_ipsec () {
	# undefined
	builtin autoload -XUz
}
_ipset () {
	# undefined
	builtin autoload -XUz
}
_iptables () {
	# undefined
	builtin autoload -XUz
}
_irssi () {
	# undefined
	builtin autoload -XUz
}
_ispell () {
	# undefined
	builtin autoload -XUz
}
_iwconfig () {
	# undefined
	builtin autoload -XUz
}
_jail () {
	# undefined
	builtin autoload -XUz
}
_jails () {
	# undefined
	builtin autoload -XUz
}
_java () {
	# undefined
	builtin autoload -XUz
}
_java_class () {
	# undefined
	builtin autoload -XUz
}
_jexec () {
	# undefined
	builtin autoload -XUz
}
_jls () {
	# undefined
	builtin autoload -XUz
}
_jobs () {
	# undefined
	builtin autoload -XUz
}
_jobs_bg () {
	# undefined
	builtin autoload -XUz
}
_jobs_builtin () {
	# undefined
	builtin autoload -XUz
}
_jobs_fg () {
	# undefined
	builtin autoload -XUz
}
_joe () {
	# undefined
	builtin autoload -XUz
}
_join () {
	# undefined
	builtin autoload -XUz
}
_jot () {
	# undefined
	builtin autoload -XUz
}
_journalctl () {
	# undefined
	builtin autoload -XUz
}
_jq () {
	# undefined
	builtin autoload -XUz
}
_kdeconnect () {
	# undefined
	builtin autoload -XUz
}
_kdump () {
	# undefined
	builtin autoload -XUz
}
_kfmclient () {
	# undefined
	builtin autoload -XUz
}
_kill () {
	# undefined
	builtin autoload -XUz
}
_killall () {
	# undefined
	builtin autoload -XUz
}
_kitty () {
	# undefined
	builtin autoload -XUz
}
_kld () {
	# undefined
	builtin autoload -XUz
}
_knock () {
	# undefined
	builtin autoload -XUz
}
_kpartx () {
	# undefined
	builtin autoload -XUz
}
_ktrace () {
	# undefined
	builtin autoload -XUz
}
_ktrace_points () {
	# undefined
	builtin autoload -XUz
}
_kvno () {
	# undefined
	builtin autoload -XUz
}
_last () {
	# undefined
	builtin autoload -XUz
}
_ld_debug () {
	# undefined
	builtin autoload -XUz
}
_ldap () {
	# undefined
	builtin autoload -XUz
}
_ldconfig () {
	# undefined
	builtin autoload -XUz
}
_ldd () {
	# undefined
	builtin autoload -XUz
}
_less () {
	# undefined
	builtin autoload -XUz
}
_lha () {
	# undefined
	builtin autoload -XUz
}
_libvirt () {
	# undefined
	builtin autoload -XUz
}
_lighttpd () {
	# undefined
	builtin autoload -XUz
}
_limit () {
	# undefined
	builtin autoload -XUz
}
_limits () {
	# undefined
	builtin autoload -XUz
}
_links () {
	# undefined
	builtin autoload -XUz
}
_lintian () {
	# undefined
	builtin autoload -XUz
}
_list () {
	# undefined
	builtin autoload -XUz
}
_list_files () {
	# undefined
	builtin autoload -XUz
}
_lldb () {
	# undefined
	builtin autoload -XUz
}
_ln () {
	# undefined
	builtin autoload -XUz
}
_loadkeys () {
	# undefined
	builtin autoload -XUz
}
_locale () {
	# undefined
	builtin autoload -XUz
}
_localectl () {
	# undefined
	builtin autoload -XUz
}
_localedef () {
	# undefined
	builtin autoload -XUz
}
_locales () {
	# undefined
	builtin autoload -XUz
}
_locate () {
	# undefined
	builtin autoload -XUz
}
_logger () {
	# undefined
	builtin autoload -XUz
}
_logical_volumes () {
	# undefined
	builtin autoload -XUz
}
_login_classes () {
	# undefined
	builtin autoload -XUz
}
_loginctl () {
	# undefined
	builtin autoload -XUz
}
_look () {
	# undefined
	builtin autoload -XUz
}
_losetup () {
	# undefined
	builtin autoload -XUz
}
_lp () {
	# undefined
	builtin autoload -XUz
}
_ls () {
	# undefined
	builtin autoload -XUz
}
_lsattr () {
	# undefined
	builtin autoload -XUz
}
_lsblk () {
	# undefined
	builtin autoload -XUz
}
_lscfg () {
	# undefined
	builtin autoload -XUz
}
_lsdev () {
	# undefined
	builtin autoload -XUz
}
_lslv () {
	# undefined
	builtin autoload -XUz
}
_lsns () {
	# undefined
	builtin autoload -XUz
}
_lsof () {
	# undefined
	builtin autoload -XUz
}
_lspv () {
	# undefined
	builtin autoload -XUz
}
_lsusb () {
	# undefined
	builtin autoload -XUz
}
_lsvg () {
	# undefined
	builtin autoload -XUz
}
_ltrace () {
	# undefined
	builtin autoload -XUz
}
_lua () {
	# undefined
	builtin autoload -XUz
}
_luarocks () {
	# undefined
	builtin autoload -XUz
}
_lynx () {
	# undefined
	builtin autoload -XUz
}
_lz4 () {
	# undefined
	builtin autoload -XUz
}
_lzop () {
	# undefined
	builtin autoload -XUz
}
_mac_applications () {
	# undefined
	builtin autoload -XUz
}
_mac_files_for_application () {
	# undefined
	builtin autoload -XUz
}
_machinectl () {
	# undefined
	builtin autoload -XUz
}
_madison () {
	# undefined
	builtin autoload -XUz
}
_mail () {
	# undefined
	builtin autoload -XUz
}
_mailboxes () {
	# undefined
	builtin autoload -XUz
}
_main_complete () {
	# undefined
	builtin autoload -XUz
}
_make () {
	# undefined
	builtin autoload -XUz
}
_make-kpkg () {
	# undefined
	builtin autoload -XUz
}
_man () {
	# undefined
	builtin autoload -XUz
}
_mat () {
	# undefined
	builtin autoload -XUz
}
_mat2 () {
	# undefined
	builtin autoload -XUz
}
_match () {
	# undefined
	builtin autoload -XUz
}
_math () {
	# undefined
	builtin autoload -XUz
}
_math_params () {
	# undefined
	builtin autoload -XUz
}
_matlab () {
	# undefined
	builtin autoload -XUz
}
_md5sum () {
	# undefined
	builtin autoload -XUz
}
_mdadm () {
	# undefined
	builtin autoload -XUz
}
_mdfind () {
	# undefined
	builtin autoload -XUz
}
_mdls () {
	# undefined
	builtin autoload -XUz
}
_mdutil () {
	# undefined
	builtin autoload -XUz
}
_members () {
	# undefined
	builtin autoload -XUz
}
_mencal () {
	# undefined
	builtin autoload -XUz
}
_menu () {
	# undefined
	builtin autoload -XUz
}
_mere () {
	# undefined
	builtin autoload -XUz
}
_mergechanges () {
	# undefined
	builtin autoload -XUz
}
_message () {
	# undefined
	builtin autoload -XUz
}
_mh () {
	# undefined
	builtin autoload -XUz
}
_mii-tool () {
	# undefined
	builtin autoload -XUz
}
_mime_types () {
	# undefined
	builtin autoload -XUz
}
_mixerctl () {
	# undefined
	builtin autoload -XUz
}
_mkdir () {
	# undefined
	builtin autoload -XUz
}
_mkfifo () {
	# undefined
	builtin autoload -XUz
}
_mknod () {
	# undefined
	builtin autoload -XUz
}
_mkshortcut () {
	# undefined
	builtin autoload -XUz
}
_mktemp () {
	# undefined
	builtin autoload -XUz
}
_mkzsh () {
	# undefined
	builtin autoload -XUz
}
_module () {
	# undefined
	builtin autoload -XUz
}
_module-assistant () {
	# undefined
	builtin autoload -XUz
}
_module_math_func () {
	# undefined
	builtin autoload -XUz
}
_modutils () {
	# undefined
	builtin autoload -XUz
}
_mondo () {
	# undefined
	builtin autoload -XUz
}
_monotone () {
	# undefined
	builtin autoload -XUz
}
_moosic () {
	# undefined
	builtin autoload -XUz
}
_mosh () {
	# undefined
	builtin autoload -XUz
}
_most_recent_file () {
	# undefined
	builtin autoload -XUz
}
_mount () {
	# undefined
	builtin autoload -XUz
}
_mozilla () {
	# undefined
	builtin autoload -XUz
}
_mpc () {
	# undefined
	builtin autoload -XUz
}
_mplayer () {
	# undefined
	builtin autoload -XUz
}
_mpv () {
	# undefined
	builtin autoload -XUz
}
_mt () {
	# undefined
	builtin autoload -XUz
}
_mtools () {
	# undefined
	builtin autoload -XUz
}
_mtr () {
	# undefined
	builtin autoload -XUz
}
_multi_parts () {
	# undefined
	builtin autoload -XUz
}
_mupdf () {
	# undefined
	builtin autoload -XUz
}
_mutt () {
	# undefined
	builtin autoload -XUz
}
_mv () {
	# undefined
	builtin autoload -XUz
}
_my_accounts () {
	# undefined
	builtin autoload -XUz
}
_myrepos () {
	# undefined
	builtin autoload -XUz
}
_mysql_utils () {
	# undefined
	builtin autoload -XUz
}
_mysqldiff () {
	# undefined
	builtin autoload -XUz
}
_nautilus () {
	# undefined
	builtin autoload -XUz
}
_nbsd_architectures () {
	# undefined
	builtin autoload -XUz
}
_ncftp () {
	# undefined
	builtin autoload -XUz
}
_nedit () {
	# undefined
	builtin autoload -XUz
}
_net_interfaces () {
	# undefined
	builtin autoload -XUz
}
_netcat () {
	# undefined
	builtin autoload -XUz
}
_netscape () {
	# undefined
	builtin autoload -XUz
}
_netstat () {
	# undefined
	builtin autoload -XUz
}
_networkctl () {
	# undefined
	builtin autoload -XUz
}
_networkmanager () {
	# undefined
	builtin autoload -XUz
}
_networksetup () {
	# undefined
	builtin autoload -XUz
}
_newsgroups () {
	# undefined
	builtin autoload -XUz
}
_next_label () {
	# undefined
	builtin autoload -XUz
}
_next_tags () {
	# undefined
	builtin autoload -XUz
}
_nginx () {
	# undefined
	builtin autoload -XUz
}
_ngrep () {
	# undefined
	builtin autoload -XUz
}
_nh () {
	# undefined
	builtin autoload -XUz
}
_nice () {
	# undefined
	builtin autoload -XUz
}
_nix () {
	# undefined
	builtin autoload -XUz
}
_nix-build () {
	# undefined
	builtin autoload -XUz
}
_nix-channel () {
	# undefined
	builtin autoload -XUz
}
_nix-collect-garbage () {
	# undefined
	builtin autoload -XUz
}
_nix-common-options () {
	# undefined
	builtin autoload -XUz
}
_nix-copy-closure () {
	# undefined
	builtin autoload -XUz
}
_nix-env () {
	# undefined
	builtin autoload -XUz
}
_nix-hash () {
	# undefined
	builtin autoload -XUz
}
_nix-install-package () {
	# undefined
	builtin autoload -XUz
}
_nix-instantiate () {
	# undefined
	builtin autoload -XUz
}
_nix-prefetch-url () {
	# undefined
	builtin autoload -XUz
}
_nix-push () {
	# undefined
	builtin autoload -XUz
}
_nix-shell () {
	# undefined
	builtin autoload -XUz
}
_nix-store () {
	# undefined
	builtin autoload -XUz
}
_nixops () {
	# undefined
	builtin autoload -XUz
}
_nixos-build-vms () {
	# undefined
	builtin autoload -XUz
}
_nixos-container () {
	# undefined
	builtin autoload -XUz
}
_nixos-generate-config () {
	# undefined
	builtin autoload -XUz
}
_nixos-install () {
	# undefined
	builtin autoload -XUz
}
_nixos-option () {
	# undefined
	builtin autoload -XUz
}
_nixos-rebuild () {
	# undefined
	builtin autoload -XUz
}
_nixos-version () {
	# undefined
	builtin autoload -XUz
}
_nkf () {
	# undefined
	builtin autoload -XUz
}
_nl () {
	# undefined
	builtin autoload -XUz
}
_nm () {
	# undefined
	builtin autoload -XUz
}
_nmap () {
	# undefined
	builtin autoload -XUz
}
_normal () {
	# undefined
	builtin autoload -XUz
}
_nothing () {
	# undefined
	builtin autoload -XUz
}
_npm () {
	# undefined
	builtin autoload -XUz
}
_nsenter () {
	# undefined
	builtin autoload -XUz
}
_nslookup () {
	# undefined
	builtin autoload -XUz
}
_numbers () {
	# undefined
	builtin autoload -XUz
}
_numfmt () {
	# undefined
	builtin autoload -XUz
}
_nvram () {
	# undefined
	builtin autoload -XUz
}
_objdump () {
	# undefined
	builtin autoload -XUz
}
_object_classes () {
	# undefined
	builtin autoload -XUz
}
_object_files () {
	# undefined
	builtin autoload -XUz
}
_obsd_architectures () {
	# undefined
	builtin autoload -XUz
}
_od () {
	# undefined
	builtin autoload -XUz
}
_okular () {
	# undefined
	builtin autoload -XUz
}
_oldlist () {
	# undefined
	builtin autoload -XUz
}
_omz () {
	local -a cmds subcmds
	cmds=('changelog:Print the changelog' 'help:Usage information' 'plugin:Manage plugins' 'pr:Manage Oh My Zsh Pull Requests' 'reload:Reload the current zsh session' 'shop:Open the Oh My Zsh shop' 'theme:Manage themes' 'update:Update Oh My Zsh' 'version:Show the version') 
	if (( CURRENT == 2 ))
	then
		_describe 'command' cmds
	elif (( CURRENT == 3 ))
	then
		case "$words[2]" in
			(changelog) local -a refs
				refs=("${(@f)$(builtin cd -q "$ZSH"; command git for-each-ref --format="%(refname:short):%(subject)" refs/heads refs/tags)}") 
				_describe 'command' refs ;;
			(plugin) subcmds=('disable:Disable plugin(s)' 'enable:Enable plugin(s)' 'info:Get plugin information' 'list:List plugins' 'load:Load plugin(s)') 
				_describe 'command' subcmds ;;
			(pr) subcmds=('clean:Delete all Pull Request branches' 'test:Test a Pull Request') 
				_describe 'command' subcmds ;;
			(theme) subcmds=('list:List themes' 'set:Set a theme in your .zshrc file' 'use:Load a theme') 
				_describe 'command' subcmds ;;
		esac
	elif (( CURRENT == 4 ))
	then
		case "${words[2]}::${words[3]}" in
			(plugin::(disable|enable|load)) local -aU valid_plugins
				if [[ "${words[3]}" = disable ]]
				then
					valid_plugins=($plugins) 
				else
					valid_plugins=("$ZSH"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t) "$ZSH_CUSTOM"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t)) 
					[[ "${words[3]}" = enable ]] && valid_plugins=(${valid_plugins:|plugins}) 
				fi
				_describe 'plugin' valid_plugins ;;
			(plugin::info) local -aU plugins
				plugins=("$ZSH"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t) "$ZSH_CUSTOM"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t)) 
				_describe 'plugin' plugins ;;
			(plugin::list) local -a opts
				opts=('--enabled:List enabled plugins only') 
				_describe -o 'options' opts ;;
			(theme::(set|use)) local -aU themes
				themes=("$ZSH"/themes/*.zsh-theme(-.N:t:r) "$ZSH_CUSTOM"/**/*.zsh-theme(-.N:r:gs:"$ZSH_CUSTOM"/themes/:::gs:"$ZSH_CUSTOM"/:::)) 
				_describe 'theme' themes ;;
		esac
	elif (( CURRENT > 4 ))
	then
		case "${words[2]}::${words[3]}" in
			(plugin::(enable|disable|load)) local -aU valid_plugins
				if [[ "${words[3]}" = disable ]]
				then
					valid_plugins=($plugins) 
				else
					valid_plugins=("$ZSH"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t) "$ZSH_CUSTOM"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t)) 
					[[ "${words[3]}" = enable ]] && valid_plugins=(${valid_plugins:|plugins}) 
				fi
				local -a args
				args=(${words[4,$(( CURRENT - 1))]}) 
				valid_plugins=(${valid_plugins:|args}) 
				_describe 'plugin' valid_plugins ;;
		esac
	fi
	return 0
}
_omz::changelog () {
	local version=${1:-HEAD} format=${3:-"--text"} 
	if (
			builtin cd -q "$ZSH"
			! command git show-ref --verify refs/heads/$version && ! command git show-ref --verify refs/tags/$version && ! command git rev-parse --verify "${version}^{commit}"
		) &> /dev/null
	then
		cat >&2 <<EOF
Usage: ${(j: :)${(s.::.)0#_}} [version]

NOTE: <version> must be a valid branch, tag or commit.
EOF
		return 1
	fi
	ZSH="$ZSH" command zsh -f "$ZSH/tools/changelog.sh" "$version" "${2:-}" "$format"
}
_omz::confirm () {
	if [[ -n "$1" ]]
	then
		_omz::log prompt "$1" "${${functrace[1]#_}%:*}"
	fi
	read -r -k 1
	if [[ "$REPLY" != $'\n' ]]
	then
		echo
	fi
}
_omz::help () {
	cat >&2 <<EOF
Usage: omz <command> [options]

Available commands:

  help                Print this help message
  changelog           Print the changelog
  plugin <command>    Manage plugins
  pr     <command>    Manage Oh My Zsh Pull Requests
  reload              Reload the current zsh session
  shop                Open the Oh My Zsh shop
  theme  <command>    Manage themes
  update              Update Oh My Zsh
  version             Show the version

EOF
}
_omz::log () {
	setopt localoptions nopromptsubst
	local logtype=$1 
	local logname=${3:-${${functrace[1]#_}%:*}} 
	if [[ $logtype = debug && -z $_OMZ_DEBUG ]]
	then
		return
	fi
	case "$logtype" in
		(prompt) print -Pn "%S%F{blue}$logname%f%s: $2" ;;
		(debug) print -P "%F{white}$logname%f: $2" ;;
		(info) print -P "%F{green}$logname%f: $2" ;;
		(warn) print -P "%S%F{yellow}$logname%f%s: $2" ;;
		(error) print -P "%S%F{red}$logname%f%s: $2" ;;
	esac >&2
}
_omz::plugin () {
	(( $# > 0 && $+functions[$0::$1] )) || {
		cat >&2 <<EOF
Usage: ${(j: :)${(s.::.)0#_}} <command> [options]

Available commands:

  disable <plugin> Disable plugin(s)
  enable <plugin>  Enable plugin(s)
  info <plugin>    Get information of a plugin
  list [--enabled] List Oh My Zsh plugins
  load <plugin>    Load plugin(s)

EOF
		return 1
	}
	local command="$1" 
	shift
	$0::$command "$@"
}
_omz::plugin::disable () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <plugin> [...]" >&2
		return 1
	fi
	local -a dis_plugins
	for plugin in "$@"
	do
		if [[ ${plugins[(Ie)$plugin]} -eq 0 ]]
		then
			_omz::log warn "plugin '$plugin' is not enabled."
			continue
		fi
		dis_plugins+=("$plugin") 
	done
	if [[ ${#dis_plugins} -eq 0 ]]
	then
		return 1
	fi
	local awk_subst_plugins="  gsub(/[ \t]+(${(j:|:)dis_plugins})[ \t]+/, \" \") # with spaces before or after
  gsub(/[ \t]+(${(j:|:)dis_plugins})$/, \"\")       # with spaces before and EOL
  gsub(/^(${(j:|:)dis_plugins})[ \t]+/, \"\")       # with BOL and spaces after

  gsub(/\((${(j:|:)dis_plugins})[ \t]+/, \"(\")     # with parenthesis before and spaces after
  gsub(/[ \t]+(${(j:|:)dis_plugins})\)/, \")\")     # with spaces before or parenthesis after
  gsub(/\((${(j:|:)dis_plugins})\)/, \"()\")        # with only parentheses

  gsub(/^(${(j:|:)dis_plugins})\)/, \")\")          # with BOL and closing parenthesis
  gsub(/\((${(j:|:)dis_plugins})$/, \"(\")          # with opening parenthesis and EOL
" 
	local awk_script="
# if plugins=() is in oneline form, substitute disabled plugins and go to next line
/^[ \t]*plugins=\([^#]+\).*\$/ {
  $awk_subst_plugins
  print \$0
  next
}

# if plugins=() is in multiline form, enable multi flag and disable plugins if they're there
/^[ \t]*plugins=\(/ {
  multi=1
  $awk_subst_plugins
  print \$0
  next
}

# if multi flag is enabled and we find a valid closing parenthesis, remove plugins and disable multi flag
multi == 1 && /^[^#]*\)/ {
  multi=0
  $awk_subst_plugins
  print \$0
  next
}

multi == 1 && length(\$0) > 0 {
  $awk_subst_plugins
  if (length(\$0) > 0) print \$0
  next
}

{ print \$0 }
" 
	local zdot="${ZDOTDIR:-$HOME}" 
	local zshrc="${${:-"${zdot}/.zshrc"}:A}" 
	awk "$awk_script" "$zshrc" > "$zdot/.zshrc.new" && command cp -f "$zshrc" "$zdot/.zshrc.bck" && command mv -f "$zdot/.zshrc.new" "$zshrc"
	[[ $? -eq 0 ]] || {
		local ret=$? 
		_omz::log error "error disabling plugins."
		return $ret
	}
	if ! command zsh -n "$zdot/.zshrc"
	then
		_omz::log error "broken syntax in '"${zdot/#$HOME/\~}/.zshrc"'. Rolling back changes..."
		command mv -f "$zdot/.zshrc.bck" "$zshrc"
		return 1
	fi
	_omz::log info "plugins disabled: ${(j:, :)dis_plugins}."
	[[ ! -o interactive ]] || _omz::reload
}
_omz::plugin::enable () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <plugin> [...]" >&2
		return 1
	fi
	local -a add_plugins
	for plugin in "$@"
	do
		if [[ ${plugins[(Ie)$plugin]} -ne 0 ]]
		then
			_omz::log warn "plugin '$plugin' is already enabled."
			continue
		fi
		add_plugins+=("$plugin") 
	done
	if [[ ${#add_plugins} -eq 0 ]]
	then
		return 1
	fi
	local awk_script="
# if plugins=() is in oneline form, substitute ) with new plugins and go to the next line
/^[ \t]*plugins=\([^#]+\).*\$/ {
  sub(/\)/, \" $add_plugins&\")
  print \$0
  next
}

# if plugins=() is in multiline form, enable multi flag and indent by default with 2 spaces
/^[ \t]*plugins=\(/ {
  multi=1
  indent=\"  \"
  print \$0
  next
}

# if multi flag is enabled and we find a valid closing parenthesis,
# add new plugins with proper indent and disable multi flag
multi == 1 && /^[^#]*\)/ {
  multi=0
  split(\"$add_plugins\",p,\" \")
  for (i in p) {
    print indent p[i]
  }
  print \$0
  next
}

# if multi flag is enabled and we didnt find a closing parenthesis,
# get the indentation level to match when adding plugins
multi == 1 && /^[^#]*/ {
  indent=\"\"
  for (i = 1; i <= length(\$0); i++) {
    char=substr(\$0, i, 1)
    if (char == \" \" || char == \"\t\") {
      indent = indent char
    } else {
      break
    }
  }
}

{ print \$0 }
" 
	local zdot="${ZDOTDIR:-$HOME}" 
	local zshrc="${${:-"${zdot}/.zshrc"}:A}" 
	awk "$awk_script" "$zshrc" > "$zdot/.zshrc.new" && command cp -f "$zshrc" "$zdot/.zshrc.bck" && command mv -f "$zdot/.zshrc.new" "$zshrc"
	[[ $? -eq 0 ]] || {
		local ret=$? 
		_omz::log error "error enabling plugins."
		return $ret
	}
	if ! command zsh -n "$zdot/.zshrc"
	then
		_omz::log error "broken syntax in '"${zdot/#$HOME/\~}/.zshrc"'. Rolling back changes..."
		command mv -f "$zdot/.zshrc.bck" "$zshrc"
		return 1
	fi
	_omz::log info "plugins enabled: ${(j:, :)add_plugins}."
	[[ ! -o interactive ]] || _omz::reload
}
_omz::plugin::info () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <plugin>" >&2
		return 1
	fi
	local readme
	for readme in "$ZSH_CUSTOM/plugins/$1/README.md" "$ZSH/plugins/$1/README.md"
	do
		if [[ -f "$readme" ]]
		then
			if [[ ! -t 1 ]]
			then
				cat "$readme"
				return $?
			fi
			case 1 in
				(${+commands[glow]}) glow -p "$readme" ;;
				(${+commands[bat]}) bat -l md --style plain "$readme" ;;
				(${+commands[less]}) less "$readme" ;;
				(*) cat "$readme" ;;
			esac
			return $?
		fi
	done
	if [[ -d "$ZSH_CUSTOM/plugins/$1" || -d "$ZSH/plugins/$1" ]]
	then
		_omz::log error "the '$1' plugin doesn't have a README file"
	else
		_omz::log error "'$1' plugin not found"
	fi
	return 1
}
_omz::plugin::list () {
	local -a custom_plugins builtin_plugins
	if [[ "$1" == "--enabled" ]]
	then
		local plugin
		for plugin in "${plugins[@]}"
		do
			if [[ -d "${ZSH_CUSTOM}/plugins/${plugin}" ]]
			then
				custom_plugins+=("${plugin}") 
			elif [[ -d "${ZSH}/plugins/${plugin}" ]]
			then
				builtin_plugins+=("${plugin}") 
			fi
		done
	else
		custom_plugins=("$ZSH_CUSTOM"/plugins/*(-/N:t)) 
		builtin_plugins=("$ZSH"/plugins/*(-/N:t)) 
	fi
	if [[ ! -t 1 ]]
	then
		print -l ${(q-)custom_plugins} ${(q-)builtin_plugins}
		return
	fi
	if (( ${#custom_plugins} ))
	then
		print -P "%U%BCustom plugins%b%u:"
		print -lac ${(q-)custom_plugins}
	fi
	if (( ${#builtin_plugins} ))
	then
		(( ${#custom_plugins} )) && echo
		print -P "%U%BBuilt-in plugins%b%u:"
		print -lac ${(q-)builtin_plugins}
	fi
}
_omz::plugin::load () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <plugin> [...]" >&2
		return 1
	fi
	local plugin base has_completion=0 
	for plugin in "$@"
	do
		if [[ -d "$ZSH_CUSTOM/plugins/$plugin" ]]
		then
			base="$ZSH_CUSTOM/plugins/$plugin" 
		elif [[ -d "$ZSH/plugins/$plugin" ]]
		then
			base="$ZSH/plugins/$plugin" 
		else
			_omz::log warn "plugin '$plugin' not found"
			continue
		fi
		if [[ ! -f "$base/_$plugin" && ! -f "$base/$plugin.plugin.zsh" ]]
		then
			_omz::log warn "'$plugin' is not a valid plugin"
			continue
		elif (( ! ${fpath[(Ie)$base]} ))
		then
			fpath=("$base" $fpath) 
		fi
		local -a comp_files
		comp_files=($base/_*(N)) 
		has_completion=$(( $#comp_files > 0 )) 
		if [[ -f "$base/$plugin.plugin.zsh" ]]
		then
			source "$base/$plugin.plugin.zsh"
		fi
	done
	if (( has_completion ))
	then
		compinit -D -d "$_comp_dumpfile"
	fi
}
_omz::pr () {
	(( $# > 0 && $+functions[$0::$1] )) || {
		cat >&2 <<EOF
Usage: ${(j: :)${(s.::.)0#_}} <command> [options]

Available commands:

  clean                       Delete all PR branches (ohmyzsh/pull-*)
  test <PR_number_or_URL>     Fetch PR #NUMBER and rebase against master

EOF
		return 1
	}
	local command="$1" 
	shift
	$0::$command "$@"
}
_omz::pr::clean () {
	(
		set -e
		builtin cd -q "$ZSH"
		local fmt branches
		fmt="%(color:bold blue)%(align:18,right)%(refname:short)%(end)%(color:reset) %(color:dim bold red)%(objectname:short)%(color:reset) %(color:yellow)%(contents:subject)" 
		branches="$(command git for-each-ref --sort=-committerdate --color --format="$fmt" "refs/heads/ohmyzsh/pull-*")" 
		if [[ -z "$branches" ]]
		then
			_omz::log info "there are no Pull Request branches to remove."
			return
		fi
		echo "$branches\n"
		_omz::confirm "do you want remove these Pull Request branches? [Y/n] "
		[[ "$REPLY" != [yY$'\n'] ]] && return
		_omz::log info "removing all Oh My Zsh Pull Request branches..."
		command git branch --list 'ohmyzsh/pull-*' | while read branch
		do
			command git branch -D "$branch"
		done
	)
}
_omz::pr::test () {
	if [[ "$1" = https://* ]]
	then
		1="${1:t}" 
	fi
	if ! [[ -n "$1" && "$1" =~ ^[[:digit:]]+$ ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <PR_NUMBER_or_URL>" >&2
		return 1
	fi
	local branch
	branch=$(builtin cd -q "$ZSH"; git symbolic-ref --short HEAD)  || {
		_omz::log error "error when getting the current git branch. Aborting..."
		return 1
	}
	(
		set -e
		builtin cd -q "$ZSH"
		command git remote -v | while read remote url _
		do
			case "$url" in
				(https://github.com/ohmyzsh/ohmyzsh(|.git)) found=1 
					break ;;
				(git@github.com:ohmyzsh/ohmyzsh(|.git)) found=1 
					break ;;
			esac
		done
		(( $found )) || {
			_omz::log error "could not find the ohmyzsh git remote. Aborting..."
			return 1
		}
		_omz::log info "checking if PR #$1 has the 'testers needed' label..."
		local pr_json label label_id="MDU6TGFiZWw4NzY1NTkwNA==" 
		pr_json=$(
      curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/ohmyzsh/ohmyzsh/pulls/$1"
    ) 
		if [[ $? -gt 0 || -z "$pr_json" ]]
		then
			_omz::log error "error when trying to fetch PR #$1 from GitHub."
			return 1
		fi
		if (( $+commands[jq] ))
		then
			label="$(command jq ".labels.[] | select(.node_id == \"$label_id\")" <<< "$pr_json")" 
		else
			label="$(command grep "\"$label_id\"" <<< "$pr_json" 2>/dev/null)" 
		fi
		if [[ -z "$label" ]]
		then
			_omz::log warn "PR #$1 does not have the 'testers needed' label. This means that the PR"
			_omz::log warn "has not been reviewed by a maintainer and may contain malicious code."
			_omz::log prompt "Do you want to continue testing it? [yes/N] "
			builtin read -r
			if [[ "${REPLY:l}" != yes ]]
			then
				_omz::log error "PR test canceled. Please ask a maintainer to review and label the PR."
				return 1
			else
				_omz::log warn "Continuing to check out and test PR #$1. Be careful!"
			fi
		fi
		_omz::log info "fetching PR #$1 to ohmyzsh/pull-$1..."
		command git fetch -f "$remote" refs/pull/$1/head:ohmyzsh/pull-$1 || {
			_omz::log error "error when trying to fetch PR #$1."
			return 1
		}
		_omz::log info "rebasing PR #$1..."
		local ret gpgsign
		{
			gpgsign=$(command git config --local commit.gpgsign 2>/dev/null)  || ret=$? 
			[[ $ret -ne 129 ]] || gpgsign=$(command git config commit.gpgsign 2>/dev/null) 
			command git config commit.gpgsign false
			command git rebase master ohmyzsh/pull-$1 || {
				command git rebase --abort &> /dev/null
				_omz::log warn "could not rebase PR #$1 on top of master."
				_omz::log warn "you might not see the latest stable changes."
				_omz::log info "run \`zsh\` to test the changes."
				return 1
			}
		} always {
			case "$gpgsign" in
				("") command git config --unset commit.gpgsign ;;
				(*) command git config commit.gpgsign "$gpgsign" ;;
			esac
		}
		_omz::log info "fetch of PR #${1} successful."
	)
	[[ $? -eq 0 ]] || return 1
	_omz::log info "running \`zsh\` to test the changes. Run \`exit\` to go back."
	command zsh -l
	_omz::confirm "do you want to go back to the previous branch? [Y/n] "
	[[ "$REPLY" != [yY$'\n'] ]] && return
	(
		set -e
		builtin cd -q "$ZSH"
		command git checkout "$branch" -- || {
			_omz::log error "could not go back to the previous branch ('$branch')."
			return 1
		}
	)
}
_omz::reload () {
	command rm -f $_comp_dumpfile $ZSH_COMPDUMP
	local zsh="${ZSH_ARGZERO:-${functrace[-1]%:*}}" 
	[[ "$zsh" = -* || -o login ]] && exec -l "${zsh#-}" || exec "$zsh"
}
_omz::shop () {
	local shop_url="https://commitgoods.com/collections/oh-my-zsh" 
	_omz::log info "Opening Oh My Zsh shop in your browser..."
	_omz::log info "$shop_url"
	open_command "$shop_url"
}
_omz::theme () {
	(( $# > 0 && $+functions[$0::$1] )) || {
		cat >&2 <<EOF
Usage: ${(j: :)${(s.::.)0#_}} <command> [options]

Available commands:

  list            List all available Oh My Zsh themes
  set <theme>     Set a theme in your .zshrc file
  use <theme>     Load a theme

EOF
		return 1
	}
	local command="$1" 
	shift
	$0::$command "$@"
}
_omz::theme::list () {
	local -a custom_themes builtin_themes
	custom_themes=("$ZSH_CUSTOM"/**/*.zsh-theme(-.N:r:gs:"$ZSH_CUSTOM"/themes/:::gs:"$ZSH_CUSTOM"/:::)) 
	builtin_themes=("$ZSH"/themes/*.zsh-theme(-.N:t:r)) 
	if [[ ! -t 1 ]]
	then
		print -l ${(q-)custom_themes} ${(q-)builtin_themes}
		return
	fi
	if [[ -n "$ZSH_THEME" ]]
	then
		print -Pn "%U%BCurrent theme%b%u: "
		[[ $ZSH_THEME = random ]] && echo "$RANDOM_THEME (via random)" || echo "$ZSH_THEME"
		echo
	fi
	if (( ${#custom_themes} ))
	then
		print -P "%U%BCustom themes%b%u:"
		print -lac ${(q-)custom_themes}
		echo
	fi
	print -P "%U%BBuilt-in themes%b%u:"
	print -lac ${(q-)builtin_themes}
}
_omz::theme::set () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <theme>" >&2
		return 1
	fi
	if [[ ! -f "$ZSH_CUSTOM/$1.zsh-theme" ]] && [[ ! -f "$ZSH_CUSTOM/themes/$1.zsh-theme" ]] && [[ ! -f "$ZSH/themes/$1.zsh-theme" ]]
	then
		_omz::log error "%B$1%b theme not found"
		return 1
	fi
	local awk_script='
!set && /^[ \t]*ZSH_THEME=[^#]+.*$/ {
  set=1
  sub(/^[ \t]*ZSH_THEME=[^#]+.*$/, "ZSH_THEME=\"'$1'\" # set by `omz`")
  print $0
  next
}

{ print $0 }

END {
  # If no ZSH_THEME= line was found, return an error
  if (!set) exit 1
}
' 
	local zdot="${ZDOTDIR:-$HOME}" 
	local zshrc="${${:-"${zdot}/.zshrc"}:A}" 
	awk "$awk_script" "$zshrc" > "$zdot/.zshrc.new" || {
		cat <<EOF
ZSH_THEME="$1" # set by \`omz\`

EOF
		cat "$zdot/.zshrc"
	} > "$zdot/.zshrc.new" && command cp -f "$zshrc" "$zdot/.zshrc.bck" && command mv -f "$zdot/.zshrc.new" "$zshrc"
	[[ $? -eq 0 ]] || {
		local ret=$? 
		_omz::log error "error setting theme."
		return $ret
	}
	if ! command zsh -n "$zdot/.zshrc"
	then
		_omz::log error "broken syntax in '"${zdot/#$HOME/\~}/.zshrc"'. Rolling back changes..."
		command mv -f "$zdot/.zshrc.bck" "$zshrc"
		return 1
	fi
	_omz::log info "'$1' theme set correctly."
	[[ ! -o interactive ]] || _omz::reload
}
_omz::theme::use () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <theme>" >&2
		return 1
	fi
	if [[ -f "$ZSH_CUSTOM/$1.zsh-theme" ]]
	then
		source "$ZSH_CUSTOM/$1.zsh-theme"
	elif [[ -f "$ZSH_CUSTOM/themes/$1.zsh-theme" ]]
	then
		source "$ZSH_CUSTOM/themes/$1.zsh-theme"
	elif [[ -f "$ZSH/themes/$1.zsh-theme" ]]
	then
		source "$ZSH/themes/$1.zsh-theme"
	else
		_omz::log error "%B$1%b theme not found"
		return 1
	fi
	ZSH_THEME="$1" 
	[[ $1 = random ]] || unset RANDOM_THEME
}
_omz::update () {
	(( $+commands[git] )) || {
		_omz::log error "git is not installed. Aborting..."
		return 1
	}
	[[ "$1" != --unattended ]] || {
		_omz::log error "the \`\e[2m--unattended\e[0m\` flag is no longer supported, use the \`\e[2mupgrade.sh\e[0m\` script instead."
		_omz::log error "for more information see https://github.com/ohmyzsh/ohmyzsh/wiki/FAQ#how-do-i-update-oh-my-zsh"
		return 1
	}
	local last_commit=$(builtin cd -q "$ZSH"; git rev-parse HEAD 2>/dev/null) 
	[[ $? -eq 0 ]] || {
		_omz::log error "\`$ZSH\` is not a git directory. Aborting..."
		return 1
	}
	zstyle -s ':omz:update' verbose verbose_mode || verbose_mode=default 
	ZSH="$ZSH" command zsh -f "$ZSH/tools/upgrade.sh" -i -v $verbose_mode || return $?
	zmodload zsh/datetime
	echo "LAST_EPOCH=$(( EPOCHSECONDS / 60 / 60 / 24 ))" >| "${ZSH_CACHE_DIR}/.zsh-update"
	command rm -rf "$ZSH/log/update.lock"
	if [[ "$(builtin cd -q "$ZSH"; git rev-parse HEAD)" != "$last_commit" ]]
	then
		local zsh="${ZSH_ARGZERO:-${functrace[-1]%:*}}" 
		[[ "$zsh" = -* || -o login ]] && exec -l "${zsh#-}" || exec "$zsh"
	fi
}
_omz::version () {
	(
		builtin cd -q "$ZSH"
		local version
		version=$(command git describe --tags HEAD 2>/dev/null)  || version=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)  || version=$(command git name-rev --no-undefined --name-only --exclude="remotes/*" HEAD 2>/dev/null)  || version="<detached>" 
		local commit=$(command git rev-parse --short HEAD 2>/dev/null) 
		printf "%s (%s)\n" "$version" "$commit"
	)
}
_omz_async_callback () {
	emulate -L zsh
	local fd=$1 
	local err=$2 
	if [[ -z "$err" || "$err" == "hup" ]]
	then
		local handler="${(k)_OMZ_ASYNC_FDS[(r)$fd]}" 
		local old_output="${_OMZ_ASYNC_OUTPUT[$handler]}" 
		IFS= read -r -u $fd -d '' "_OMZ_ASYNC_OUTPUT[$handler]"
		if [[ "$old_output" != "${_OMZ_ASYNC_OUTPUT[$handler]}" ]]
		then
			zle .reset-prompt
			zle -R
		fi
		exec {fd}<&-
	fi
	zle -F "$fd"
	_OMZ_ASYNC_FDS[$handler]=-1 
	_OMZ_ASYNC_PIDS[$handler]=-1 
}
_omz_async_request () {
	setopt localoptions noksharrays unset
	local -i ret=$? 
	typeset -gA _OMZ_ASYNC_FDS _OMZ_ASYNC_PIDS _OMZ_ASYNC_OUTPUT
	local handler
	for handler in ${_omz_async_functions}
	do
		(( ${+functions[$handler]} )) || continue
		local fd=${_OMZ_ASYNC_FDS[$handler]:--1} 
		local pid=${_OMZ_ASYNC_PIDS[$handler]:--1} 
		if (( fd != -1 && pid != -1 )) && {
				true <&$fd
			} 2> /dev/null
		then
			exec {fd}<&-
			zle -F $fd
			if [[ -o MONITOR ]]
			then
				kill -TERM -$pid 2> /dev/null
			else
				kill -TERM $pid 2> /dev/null
			fi
		fi
		_OMZ_ASYNC_FDS[$handler]=-1 
		_OMZ_ASYNC_PIDS[$handler]=-1 
		exec {fd}< <(
      # Tell parent process our PID
      builtin echo ${sysparams[pid]}
      # Set exit code for the handler if used
      () { return $ret }
      # Run the async function handler
      $handler
    )
		_OMZ_ASYNC_FDS[$handler]=$fd 
		is-at-least 5.8 || command true
		read -u $fd "_OMZ_ASYNC_PIDS[$handler]"
		zle -F "$fd" _omz_async_callback
	done
}
_omz_diag_dump_check_core_commands () {
	builtin echo "Core command check:"
	local redefined name builtins externals reserved_words
	redefined=() 
	reserved_words=(do done esac then elif else fi for case if while function repeat time until select coproc nocorrect foreach end '!' '[[' '{' '}') 
	builtins=(alias autoload bg bindkey break builtin bye cd chdir command comparguments compcall compctl compdescribe compfiles compgroups compquote comptags comptry compvalues continue dirs disable disown echo echotc echoti emulate enable eval exec exit false fc fg functions getln getopts hash jobs kill let limit log logout noglob popd print printf pushd pushln pwd r read rehash return sched set setopt shift source suspend test times trap true ttyctl type ulimit umask unalias unfunction unhash unlimit unset unsetopt vared wait whence where which zcompile zle zmodload zparseopts zregexparse zstyle) 
	if is-at-least 5.1
	then
		reserved_word+=(declare export integer float local readonly typeset) 
	else
		builtins+=(declare export integer float local readonly typeset) 
	fi
	builtins_fatal=(builtin command local) 
	externals=(zsh) 
	for name in $reserved_words
	do
		if [[ $(builtin whence -w $name) != "$name: reserved" ]]
		then
			builtin echo "reserved word '$name' has been redefined"
			builtin which $name
			redefined+=$name 
		fi
	done
	for name in $builtins
	do
		if [[ $(builtin whence -w $name) != "$name: builtin" ]]
		then
			builtin echo "builtin '$name' has been redefined"
			builtin which $name
			redefined+=$name 
		fi
	done
	for name in $externals
	do
		if [[ $(builtin whence -w $name) != "$name: command" ]]
		then
			builtin echo "command '$name' has been redefined"
			builtin which $name
			redefined+=$name 
		fi
	done
	if [[ -n "$redefined" ]]
	then
		builtin echo "SOME CORE COMMANDS HAVE BEEN REDEFINED: $redefined"
	else
		builtin echo "All core commands are defined normally"
	fi
}
_omz_diag_dump_echo_file_w_header () {
	local file=$1 
	if [[ -f $file || -h $file ]]
	then
		builtin echo "========== $file =========="
		if [[ -h $file ]]
		then
			builtin echo "==========    ( => ${file:A} )   =========="
		fi
		command cat $file
		builtin echo "========== end $file =========="
		builtin echo
	elif [[ -d $file ]]
	then
		builtin echo "File '$file' is a directory"
	elif [[ ! -e $file ]]
	then
		builtin echo "File '$file' does not exist"
	else
		command ls -lad "$file"
	fi
}
_omz_diag_dump_one_big_text () {
	local program programs progfile md5
	builtin echo oh-my-zsh diagnostic dump
	builtin echo
	builtin echo $outfile
	builtin echo
	command date
	command uname -a
	builtin echo OSTYPE=$OSTYPE
	builtin echo ZSH_VERSION=$ZSH_VERSION
	builtin echo User: $USERNAME
	builtin echo umask: $(umask)
	builtin echo
	_omz_diag_dump_os_specific_version
	builtin echo
	programs=(sh zsh ksh bash sed cat grep ls find git posh) 
	local progfile="" extra_str="" sha_str="" 
	for program in $programs
	do
		extra_str="" sha_str="" 
		progfile=$(builtin which $program) 
		if [[ $? == 0 ]]
		then
			if [[ -e $progfile ]]
			then
				if builtin whence shasum &> /dev/null
				then
					sha_str=($(command shasum $progfile)) 
					sha_str=$sha_str[1] 
					extra_str+=" SHA $sha_str" 
				fi
				if [[ -h "$progfile" ]]
				then
					extra_str+=" ( -> ${progfile:A} )" 
				fi
			fi
			builtin printf '%-9s %-20s %s\n' "$program is" "$progfile" "$extra_str"
		else
			builtin echo "$program: not found"
		fi
	done
	builtin echo
	builtin echo Command Versions:
	builtin echo "zsh: $(zsh --version)"
	builtin echo "this zsh session: $ZSH_VERSION"
	builtin echo "bash: $(bash --version | command grep bash)"
	builtin echo "git: $(git --version)"
	builtin echo "grep: $(grep --version)"
	builtin echo
	_omz_diag_dump_check_core_commands || return 1
	builtin echo
	builtin echo Process state:
	builtin echo pwd: $PWD
	if builtin whence pstree &> /dev/null
	then
		builtin echo Process tree for this shell:
		pstree -p $$
	else
		ps -fT
	fi
	builtin set | command grep -a '^\(ZSH\|plugins\|TERM\|LC_\|LANG\|precmd\|chpwd\|preexec\|FPATH\|TTY\|DISPLAY\|PATH\)\|OMZ'
	builtin echo
	builtin echo Exported:
	builtin echo $(builtin export | command sed 's/=.*//')
	builtin echo
	builtin echo Locale:
	command locale
	builtin echo
	builtin echo Zsh configuration:
	builtin echo setopt: $(builtin setopt)
	builtin echo
	builtin echo zstyle:
	builtin zstyle
	builtin echo
	builtin echo 'compaudit output:'
	compaudit
	builtin echo
	builtin echo '$fpath directories:'
	command ls -lad $fpath
	builtin echo
	builtin echo oh-my-zsh installation:
	command ls -ld ~/.z*
	command ls -ld ~/.oh*
	builtin echo
	builtin echo oh-my-zsh git state:
	(
		builtin cd $ZSH && builtin echo "HEAD: $(git rev-parse HEAD)" && git remote -v && git status | command grep "[^[:space:]]"
	)
	if [[ $verbose -ge 1 ]]
	then
		(
			builtin cd $ZSH && git reflog --date=default | command grep pull
		)
	fi
	builtin echo
	if [[ -e $ZSH_CUSTOM ]]
	then
		local custom_dir=$ZSH_CUSTOM 
		if [[ -h $custom_dir ]]
		then
			custom_dir=$(builtin cd $custom_dir && pwd -P) 
		fi
		builtin echo "oh-my-zsh custom dir:"
		builtin echo "   $ZSH_CUSTOM ($custom_dir)"
		(
			builtin cd ${custom_dir:h} && command find ${custom_dir:t} -name .git -prune -o -print
		)
		builtin echo
	fi
	if [[ $verbose -ge 1 ]]
	then
		builtin echo "bindkey:"
		builtin bindkey
		builtin echo
		builtin echo "infocmp:"
		command infocmp -L
		builtin echo
	fi
	local zdotdir=${ZDOTDIR:-$HOME} 
	builtin echo "Zsh configuration files:"
	local cfgfile cfgfiles
	cfgfiles=(/etc/zshenv /etc/zprofile /etc/zshrc /etc/zlogin /etc/zlogout $zdotdir/.zshenv $zdotdir/.zprofile $zdotdir/.zshrc $zdotdir/.zlogin $zdotdir/.zlogout ~/.zsh.pre-oh-my-zsh /etc/bashrc /etc/profile ~/.bashrc ~/.profile ~/.bash_profile ~/.bash_logout) 
	command ls -lad $cfgfiles 2>&1
	builtin echo
	if [[ $verbose -ge 1 ]]
	then
		for cfgfile in $cfgfiles
		do
			_omz_diag_dump_echo_file_w_header $cfgfile
		done
	fi
	builtin echo
	builtin echo "Zsh compdump files:"
	local dumpfile dumpfiles
	command ls -lad $zdotdir/.zcompdump*
	dumpfiles=($zdotdir/.zcompdump*(N)) 
	if [[ $verbose -ge 2 ]]
	then
		for dumpfile in $dumpfiles
		do
			_omz_diag_dump_echo_file_w_header $dumpfile
		done
	fi
}
_omz_diag_dump_os_specific_version () {
	local osname osver version_file version_files
	case "$OSTYPE" in
		(darwin*) osname=$(command sw_vers -productName) 
			osver=$(command sw_vers -productVersion) 
			builtin echo "OS Version: $osname $osver build $(sw_vers -buildVersion)" ;;
		(cygwin) command systeminfo | command head -n 4 | command tail -n 2 ;;
	esac
	if builtin which lsb_release > /dev/null
	then
		builtin echo "OS Release: $(command lsb_release -s -d)"
	fi
	version_files=(/etc/*-release(N) /etc/*-version(N) /etc/*_version(N)) 
	for version_file in $version_files
	do
		builtin echo "$version_file:"
		command cat "$version_file"
		builtin echo
	done
}
_omz_git_prompt_info () {
	if ! __git_prompt_git rev-parse --git-dir &> /dev/null || [[ "$(__git_prompt_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]
	then
		return 0
	fi
	local ref
	ref=$(__git_prompt_git symbolic-ref --short HEAD 2> /dev/null)  || ref=$(__git_prompt_git describe --tags --exact-match HEAD 2> /dev/null)  || ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  || return 0
	local upstream
	if (( ${+ZSH_THEME_GIT_SHOW_UPSTREAM} ))
	then
		upstream=$(__git_prompt_git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null)  && upstream=" -> ${upstream}" 
	fi
	echo "${ZSH_THEME_GIT_PROMPT_PREFIX}${ref:gs/%/%%}${upstream:gs/%/%%}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
}
_omz_git_prompt_status () {
	[[ "$(__git_prompt_git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]] && return
	local -A prefix_constant_map
	prefix_constant_map=('\?\? ' 'UNTRACKED' 'A  ' 'ADDED' 'M  ' 'MODIFIED' 'MM ' 'MODIFIED' ' M ' 'MODIFIED' 'AM ' 'MODIFIED' ' T ' 'MODIFIED' 'R  ' 'RENAMED' ' D ' 'DELETED' 'D  ' 'DELETED' 'UU ' 'UNMERGED' 'ahead' 'AHEAD' 'behind' 'BEHIND' 'diverged' 'DIVERGED' 'stashed' 'STASHED') 
	local -A constant_prompt_map
	constant_prompt_map=('UNTRACKED' "$ZSH_THEME_GIT_PROMPT_UNTRACKED" 'ADDED' "$ZSH_THEME_GIT_PROMPT_ADDED" 'MODIFIED' "$ZSH_THEME_GIT_PROMPT_MODIFIED" 'RENAMED' "$ZSH_THEME_GIT_PROMPT_RENAMED" 'DELETED' "$ZSH_THEME_GIT_PROMPT_DELETED" 'UNMERGED' "$ZSH_THEME_GIT_PROMPT_UNMERGED" 'AHEAD' "$ZSH_THEME_GIT_PROMPT_AHEAD" 'BEHIND' "$ZSH_THEME_GIT_PROMPT_BEHIND" 'DIVERGED' "$ZSH_THEME_GIT_PROMPT_DIVERGED" 'STASHED' "$ZSH_THEME_GIT_PROMPT_STASHED") 
	local status_constants
	status_constants=(UNTRACKED ADDED MODIFIED RENAMED DELETED STASHED UNMERGED AHEAD BEHIND DIVERGED) 
	local status_text
	status_text="$(__git_prompt_git status --porcelain -b 2> /dev/null)" 
	if [[ $? -eq 128 ]]
	then
		return 1
	fi
	local -A statuses_seen
	if __git_prompt_git rev-parse --verify refs/stash &> /dev/null
	then
		statuses_seen[STASHED]=1 
	fi
	local status_lines
	status_lines=("${(@f)${status_text}}") 
	if [[ "$status_lines[1]" =~ "^## [^ ]+ \[(.*)\]" ]]
	then
		local branch_statuses
		branch_statuses=("${(@s/,/)match}") 
		for branch_status in $branch_statuses
		do
			if [[ ! $branch_status =~ "(behind|diverged|ahead) ([0-9]+)?" ]]
			then
				continue
			fi
			local last_parsed_status=$prefix_constant_map[$match[1]] 
			statuses_seen[$last_parsed_status]=$match[2] 
		done
	fi
	for status_prefix in "${(@k)prefix_constant_map}"
	do
		local status_constant="${prefix_constant_map[$status_prefix]}" 
		local status_regex=$'(^|\n)'"$status_prefix" 
		if [[ "$status_text" =~ $status_regex ]]
		then
			statuses_seen[$status_constant]=1 
		fi
	done
	local status_prompt
	for status_constant in $status_constants
	do
		if (( ${+statuses_seen[$status_constant]} ))
		then
			local next_display=$constant_prompt_map[$status_constant] 
			status_prompt="$next_display$status_prompt" 
		fi
	done
	echo $status_prompt
}
_omz_register_handler () {
	setopt localoptions noksharrays unset
	typeset -ga _omz_async_functions
	if [[ -z "$1" ]] || (( ! ${+functions[$1]} )) || (( ${_omz_async_functions[(Ie)$1]} ))
	then
		return
	fi
	_omz_async_functions+=("$1") 
	if (( ! ${precmd_functions[(Ie)_omz_async_request]} )) && (( ${+functions[_omz_async_request]}))
	then
		autoload -Uz add-zsh-hook
		add-zsh-hook precmd _omz_async_request
	fi
}
_omz_source () {
	local context filepath="$1" 
	case "$filepath" in
		(lib/*) context="lib:${filepath:t:r}"  ;;
		(plugins/*) context="plugins:${filepath:h:t}"  ;;
	esac
	local disable_aliases=0 
	zstyle -T ":omz:${context}" aliases || disable_aliases=1 
	local -A aliases_pre galiases_pre
	if (( disable_aliases ))
	then
		aliases_pre=("${(@kv)aliases}") 
		galiases_pre=("${(@kv)galiases}") 
	fi
	if [[ -f "$ZSH_CUSTOM/$filepath" ]]
	then
		source "$ZSH_CUSTOM/$filepath"
	elif [[ -f "$ZSH/$filepath" ]]
	then
		source "$ZSH/$filepath"
	fi
	if (( disable_aliases ))
	then
		if (( #aliases_pre ))
		then
			aliases=("${(@kv)aliases_pre}") 
		else
			(( #aliases )) && unalias "${(@k)aliases}"
		fi
		if (( #galiases_pre ))
		then
			galiases=("${(@kv)galiases_pre}") 
		else
			(( #galiases )) && unalias "${(@k)galiases}"
		fi
	fi
}
_oomctl () {
	# undefined
	builtin autoload -XUz
}
_open () {
	# undefined
	builtin autoload -XUz
}
_opencode () {
	# undefined
	builtin autoload -XUz
}
_openstack () {
	# undefined
	builtin autoload -XUz
}
_opkg () {
	# undefined
	builtin autoload -XUz
}
_options () {
	# undefined
	builtin autoload -XUz
}
_options_set () {
	# undefined
	builtin autoload -XUz
}
_options_unset () {
	# undefined
	builtin autoload -XUz
}
_opustools () {
	# undefined
	builtin autoload -XUz
}
_osascript () {
	# undefined
	builtin autoload -XUz
}
_osc () {
	# undefined
	builtin autoload -XUz
}
_other_accounts () {
	# undefined
	builtin autoload -XUz
}
_otool () {
	# undefined
	builtin autoload -XUz
}
_p9k_all_params_eq () {
	local key
	for key in ${parameters[(I)${~1}]}
	do
		[[ ${(P)key} == $2 ]] || return
	done
}
_p9k_asdf_check_meta () {
	[[ -n $_p9k_asdf_meta_sig ]] || return
	[[ -z $^_p9k_asdf_meta_non_files(#qN) ]] || return
	local -a stat
	if (( $#_p9k_asdf_meta_files ))
	then
		zstat -A stat +mtime -- $_p9k_asdf_meta_files 2> /dev/null || return
	fi
	[[ $_p9k_asdf_meta_sig == $ASDF_CONFIG_FILE$'\0'$ASDF_DATA_DIR$'\0'${(pj:\0:)stat} ]] || return
}
_p9k_asdf_init_meta () {
	local last_sig=$_p9k_asdf_meta_sig 
	{
		local -a files
		local -i legacy_enabled
		_p9k_asdf_plugins=() 
		_p9k_asdf_file_info=() 
		local cfg=${ASDF_CONFIG_FILE:-~/.asdfrc} 
		files+=$cfg 
		if [[ -f $cfg && -r $cfg ]]
		then
			local lines=(${(@M)${(@)${(f)"$(<$cfg)"}%$'\r'}:#[[:space:]]#legacy_version_file[[:space:]]#=*}) 
			if [[ $#lines == 1 && ${${(s:=:)lines[1]}[2]} == [[:space:]]#yes[[:space:]]# ]]
			then
				legacy_enabled=1 
			fi
		fi
		local root=${ASDF_DATA_DIR:-~/.asdf} 
		files+=$root/plugins 
		if [[ -d $root/plugins ]]
		then
			local plugin
			for plugin in $root/plugins/[^[:space:]]##(/N)
			do
				files+=$root/installs/${plugin:t} 
				local -aU installed=($root/installs/${plugin:t}/[^[:space:]]##(/N:t) system) 
				_p9k_asdf_plugins[${plugin:t}]=${(j:|:)${(@b)installed}} 
				(( legacy_enabled )) || continue
				if [[ ! -e $plugin/bin ]]
				then
					files+=$plugin/bin 
				else
					local list_names=$plugin/bin/list-legacy-filenames 
					files+=$list_names 
					if [[ -x $list_names ]]
					then
						local parse=$plugin/bin/parse-legacy-file 
						local -i has_parse=0 
						files+=$parse 
						[[ -x $parse ]] && has_parse=1 
						local name
						for name in ${$($list_names 2>/dev/null)%$'\r'}
						do
							[[ $name == (*/*|.tool-versions) ]] && continue
							_p9k_asdf_file_info[$name]+="${plugin:t} $has_parse " 
						done
					fi
				fi
			done
		fi
		_p9k_asdf_meta_files=($^files(N)) 
		_p9k_asdf_meta_non_files=(${files:|_p9k_asdf_meta_files}) 
		local -a stat
		if (( $#_p9k_asdf_meta_files ))
		then
			zstat -A stat +mtime -- $_p9k_asdf_meta_files 2> /dev/null || return
		fi
		_p9k_asdf_meta_sig=$ASDF_CONFIG_FILE$'\0'$ASDF_DATA_DIR$'\0'${(pj:\0:)stat} 
		_p9k__asdf_dir2files=() 
		_p9k_asdf_file2versions=() 
	} always {
		if (( $? == 0 ))
		then
			_p9k__state_dump_scheduled=1 
			return
		fi
		[[ -n $last_sig ]] && _p9k__state_dump_scheduled=1 
		_p9k_asdf_meta_files=() 
		_p9k_asdf_meta_non_files=() 
		_p9k_asdf_meta_sig= 
		_p9k_asdf_plugins=() 
		_p9k_asdf_file_info=() 
		_p9k__asdf_dir2files=() 
		_p9k_asdf_file2versions=() 
	}
}
_p9k_asdf_parse_version_file () {
	local file=$1 
	local is_legacy=$2 
	local -a stat
	zstat -A stat +mtime $file 2> /dev/null || return
	if (( is_legacy ))
	then
		local plugin has_parse
		for plugin has_parse in $=_p9k_asdf_file_info[$file:t]
		do
			local cached=$_p9k_asdf_file2versions[$plugin:$file] 
			if [[ $cached == $stat[1]:* ]]
			then
				local v=${cached#*:} 
			else
				if (( has_parse ))
				then
					local v=($(${ASDF_DATA_DIR:-~/.asdf}/plugins/$plugin/bin/parse-legacy-file $file 2>/dev/null)) 
				else
					{
						local v=($(<$file)) 
					} 2> /dev/null
				fi
				v=(${v%$'\r'}) 
				v=${v[(r)$_p9k_asdf_plugins[$plugin]]:-$v[1]} 
				_p9k_asdf_file2versions[$plugin:$file]=$stat[1]:"$v" 
				_p9k__state_dump_scheduled=1 
			fi
			[[ -n $v ]] && : ${versions[$plugin]="$v"}
		done
	else
		local cached=$_p9k_asdf_file2versions[:$file] 
		if [[ $cached == $stat[1]:* ]]
		then
			local file_versions=(${(0)${cached#*:}}) 
		else
			local file_versions=() 
			{
				local lines=(${(@)${(@)${(f)"$(<$file)"}%$'\r'}/\#*}) 
			} 2> /dev/null
			local line
			for line in $lines
			do
				local words=($=line) 
				(( $#words > 1 )) || continue
				local installed=$_p9k_asdf_plugins[$words[1]] 
				[[ -n $installed ]] || continue
				file_versions+=($words[1] ${${words:1}[(r)$installed]:-$words[2]}) 
			done
			_p9k_asdf_file2versions[:$file]=$stat[1]:${(pj:\0:)file_versions} 
			_p9k__state_dump_scheduled=1 
		fi
		local plugin version
		for plugin version in $file_versions
		do
			: ${versions[$plugin]=$version}
		done
	fi
	return 0
}
_p9k_background () {
	[[ -n $1 ]] && _p9k__ret="%K{$1}"  || _p9k__ret="%k" 
}
_p9k_build_gap_post () {
	if [[ $1 == 1 ]]
	then
		local kind_l=first kind_u=FIRST 
	else
		local kind_l=newline kind_u=NEWLINE 
	fi
	_p9k_get_icon '' MULTILINE_${kind_u}_PROMPT_GAP_CHAR
	local char=${_p9k__ret:- } 
	_p9k_prompt_length $char
	if (( _p9k__ret != 1 || $#char != 1 ))
	then
		print -rP -- "%F{red}WARNING!%f %BMULTILINE_${kind_u}_PROMPT_GAP_CHAR%b is not one character long. Will use ' '." >&2
		print -rP -- "Either change the value of %BPOWERLEVEL9K_MULTILINE_${kind_u}_PROMPT_GAP_CHAR%b or remove it." >&2
		char=' ' 
	fi
	local style
	_p9k_color prompt_multiline_${kind_l}_prompt_gap BACKGROUND ""
	[[ -n $_p9k__ret ]] && _p9k_background $_p9k__ret
	style+=$_p9k__ret 
	_p9k_color prompt_multiline_${kind_l}_prompt_gap FOREGROUND ""
	[[ -n $_p9k__ret ]] && _p9k_foreground $_p9k__ret
	style+=$_p9k__ret 
	_p9k_escape_style $style
	style=$_p9k__ret 
	local exp=_POWERLEVEL9K_MULTILINE_${kind_u}_PROMPT_GAP_EXPANSION 
	(( $+parameters[$exp] )) && exp=${(P)exp}  || exp='${P9K_GAP}' 
	[[ $char == '.' ]] && local s=','  || local s='.' 
	_p9k__ret=$'${${_p9k__g+\n}:-'$style'${${${_p9k__m:#-*}:+' 
	_p9k__ret+='${${_p9k__'$1'g+${(pl.$((_p9k__m+1)).. .)}}:-' 
	if [[ $exp == '${P9K_GAP}' ]]
	then
		_p9k__ret+='${(pl'$s'$((_p9k__m+1))'$s$s$char$s')}' 
	else
		_p9k__ret+='${${P9K_GAP::=${(pl'$s'$((_p9k__m+1))'$s$s$char$s')}}+}' 
		_p9k__ret+='${:-"'$exp'"}' 
		style=1 
	fi
	_p9k__ret+='}' 
	if (( __p9k_ksh_arrays ))
	then
		_p9k__ret+=$'$_p9k__rprompt${_p9k_t[$((!_p9k__ind))]}}:-\n}' 
	else
		_p9k__ret+=$'$_p9k__rprompt${_p9k_t[$((1+!_p9k__ind))]}}:-\n}' 
	fi
	[[ -n $style ]] && _p9k__ret+='%b%k%f' 
	_p9k__ret+='}' 
}
_p9k_build_test_stats () {
	local code_amount="$2" 
	local tests_amount="$3" 
	local headline="$4" 
	(( code_amount > 0 )) || return
	local -F 2 ratio=$(( 100. * tests_amount / code_amount )) 
	(( ratio >= 75 )) && _p9k_prompt_segment "${1}_GOOD" "cyan" "$_p9k_color1" "$5" 0 '' "$headline: $ratio%%"
	(( ratio >= 50 && ratio < 75 )) && _p9k_prompt_segment "$1_AVG" "yellow" "$_p9k_color1" "$5" 0 '' "$headline: $ratio%%"
	(( ratio < 50 )) && _p9k_prompt_segment "$1_BAD" "red" "$_p9k_color1" "$5" 0 '' "$headline: $ratio%%"
}
_p9k_cache_ephemeral_get () {
	_p9k__cache_key="${(pj:\0:)*}" 
	local v=$_p9k__cache_ephemeral[$_p9k__cache_key] 
	[[ -n $v ]] && _p9k__cache_val=("${(@0)${v[1,-2]}}") 
}
_p9k_cache_ephemeral_set () {
	_p9k__cache_ephemeral[$_p9k__cache_key]="${(pj:\0:)*}0" 
	_p9k__cache_val=("$@") 
}
_p9k_cache_get () {
	_p9k__cache_key="${(pj:\0:)*}" 
	local v=$_p9k_cache[$_p9k__cache_key] 
	[[ -n $v ]] && _p9k__cache_val=("${(@0)${v[1,-2]}}") 
}
_p9k_cache_set () {
	_p9k_cache[$_p9k__cache_key]="${(pj:\0:)*}0" 
	_p9k__cache_val=("$@") 
	_p9k__state_dump_scheduled=1 
}
_p9k_cache_stat_get () {
	local -H stat
	local label=$1 f 
	shift
	_p9k__cache_stat_meta= 
	_p9k__cache_stat_fprint= 
	for f
	do
		if zstat -H stat -- $f 2> /dev/null
		then
			_p9k__cache_stat_meta+="${(q)f} $stat[inode] $stat[mtime] $stat[size] $stat[mode]; " 
		fi
	done
	if _p9k_cache_get $0 $label meta "$@"
	then
		if [[ $_p9k__cache_val[1] == $_p9k__cache_stat_meta ]]
		then
			_p9k__cache_stat_fprint=$_p9k__cache_val[2] 
			local -a key=($0 $label fprint "$@" "$_p9k__cache_stat_fprint") 
			_p9k__cache_fprint_key="${(pj:\0:)key}" 
			shift 2 _p9k__cache_val
			return 0
		else
			local -a key=($0 $label fprint "$@" "$_p9k__cache_val[2]") 
			_p9k__cache_ephemeral[${(pj:\0:)key}]="${(pj:\0:)_p9k__cache_val[3,-1]}0" 
		fi
	fi
	if (( $+commands[md5] ))
	then
		_p9k__cache_stat_fprint="$(md5 -- $* 2>&1)" 
	elif (( $+commands[md5sum] ))
	then
		_p9k__cache_stat_fprint="$(md5sum -b -- $* 2>&1)" 
	else
		return 1
	fi
	local meta_key=$_p9k__cache_key 
	if _p9k_cache_ephemeral_get $0 $label fprint "$@" "$_p9k__cache_stat_fprint"
	then
		_p9k__cache_fprint_key=$_p9k__cache_key 
		_p9k__cache_key=$meta_key 
		_p9k_cache_set "$_p9k__cache_stat_meta" "$_p9k__cache_stat_fprint" "$_p9k__cache_val[@]"
		shift 2 _p9k__cache_val
		return 0
	fi
	_p9k__cache_fprint_key=$_p9k__cache_key 
	_p9k__cache_key=$meta_key 
	return 1
}
_p9k_cache_stat_set () {
	_p9k_cache_set "$_p9k__cache_stat_meta" "$_p9k__cache_stat_fprint" "$@"
	_p9k__cache_key=$_p9k__cache_fprint_key 
	_p9k_cache_ephemeral_set "$@"
}
_p9k_cached_cmd () {
	local cmd=$commands[$3] 
	[[ -n $cmd ]] || return
	if ! _p9k_cache_stat_get $0" ${(q)*}" $2 $cmd
	then
		local out
		if (( $1 ))
		then
			out="$($cmd "${@:4}" 2>&1)" 
		else
			out="$($cmd "${@:4}" 2>/dev/null)" 
		fi
		_p9k_cache_stat_set $(( ! $? )) "$out"
	fi
	(( $_p9k__cache_val[1] )) || return
	_p9k__ret=$_p9k__cache_val[2] 
}
_p9k_can_configure () {
	[[ $1 == '-q' ]] && local -i q=1  || local -i q=0 
	$0_error () {
		(( q )) || print -rP "%1F[ERROR]%f %Bp10k configure%b: $1" >&2
	}
	typeset -g __p9k_cfg_path_o=${POWERLEVEL9K_CONFIG_FILE:=${ZDOTDIR:-~}/.p10k.zsh} 
	typeset -g __p9k_cfg_basename=${__p9k_cfg_path_o:t} 
	typeset -g __p9k_cfg_path=${__p9k_cfg_path_o:A} 
	typeset -g __p9k_cfg_path_u=${${${(q)__p9k_cfg_path_o}/#(#b)${(q)HOME}(|\/*)/'~'$match[1]}//\%/%%} 
	{
		[[ -e $__p9k_zd ]] || {
			$0_error "$__p9k_zd_u does not exist"
			return 1
		}
		[[ -d $__p9k_zd ]] || {
			$0_error "$__p9k_zd_u is not a directory"
			return 1
		}
		[[ ! -d $__p9k_cfg_path ]] || {
			$0_error "$__p9k_cfg_path_u is a directory"
			return 1
		}
		[[ ! -d $__p9k_zshrc ]] || {
			$0_error "$__p9k_zshrc_u is a directory"
			return 1
		}
		local dir=${__p9k_cfg_path:h} 
		while [[ ! -e $dir && $dir != ${dir:h} ]]
		do
			dir=${dir:h} 
		done
		if [[ ! -d $dir ]]
		then
			$0_error "cannot create $__p9k_cfg_path_u because ${dir//\%/%%} is not a directory"
			return 1
		fi
		if [[ ! -w $dir ]]
		then
			$0_error "cannot create $__p9k_cfg_path_u because ${dir//\%/%%} is readonly"
			return 1
		fi
		[[ ! -e $__p9k_cfg_path || -f $__p9k_cfg_path || -h $__p9k_cfg_path ]] || {
			$0_error "$__p9k_cfg_path_u is a special file"
			return 1
		}
		[[ ! -e $__p9k_zshrc || -f $__p9k_zshrc || -h $__p9k_zshrc ]] || {
			$0_error "$__p9k_zshrc_u a special file"
			return 1
		}
		[[ ! -e $__p9k_zshrc || -r $__p9k_zshrc ]] || {
			$0_error "$__p9k_zshrc_u is not readable"
			return 1
		}
		local style
		for style in lean lean-8colors classic rainbow pure
		do
			[[ -r $__p9k_root_dir/config/p10k-$style.zsh ]] || {
				$0_error "$__p9k_root_dir_u/config/p10k-$style.zsh is not readable"
				return 1
			}
		done
		(( LINES >= __p9k_wizard_lines && COLUMNS >= __p9k_wizard_columns )) || {
			$0_error "terminal size too small; must be at least $__p9k_wizard_columns columns by $__p9k_wizard_lines lines"
			return 1
		}
		[[ -t 0 && -t 1 ]] || {
			$0_error "no TTY"
			return 2
		}
		return 0
	} always {
		unfunction $0_error
	}
}
_p9k_check_visual_mode () {
	[[ ${KEYMAP:-} == vicmd ]] || return 0
	local region=${${REGION_ACTIVE:-0}/2/1} 
	[[ $region != $_p9k__region_active ]] || return 0
	_p9k__region_active=$region 
	__p9k_reset_state=2 
}
_p9k_clear_instant_prompt () {
	if (( $+__p9k_fd_0 ))
	then
		exec <&$__p9k_fd_0 {__p9k_fd_0}>&-
		unset __p9k_fd_0
	fi
	exec >&$__p9k_fd_1 2>&$__p9k_fd_2 {__p9k_fd_1}>&- {__p9k_fd_2}>&-
	unset __p9k_fd_1 __p9k_fd_2
	zshexit_functions=(${zshexit_functions:#_p9k_instant_prompt_cleanup}) 
	if (( _p9k__can_hide_cursor ))
	then
		echoti civis
		_p9k__cursor_hidden=1 
	fi
	if [[ -s $__p9k_instant_prompt_output ]]
	then
		{
			local content
			[[ $_POWERLEVEL9K_INSTANT_PROMPT == verbose ]] && content="$(<$__p9k_instant_prompt_output)" 
			local mark="${(e)${PROMPT_EOL_MARK-%B%S%#%s%b}}" 
			_p9k_prompt_length $mark
			local -i fill=$((COLUMNS > _p9k__ret ? COLUMNS - _p9k__ret : 0)) 
			local cr=$'\r' 
			local sp="${(%):-%b%k%f%s%u$mark${(pl.$fill.. .)}$cr%b%k%f%s%u%E}" 
			if (( _z4h_can_save_restore_screen == 1 && __p9k_instant_prompt_sourced >= 35 ))
			then
				-z4h-restore-screen
				unset _z4h_saved_screen
			fi
			print -rn -- $terminfo[rc]${(%):-%b%k%f%s%u}$terminfo[ed]
			local unexpected=${${content//$'\e[?'<->'c'}//$'\e['<->' q'} 
			unexpected=${(S)unexpected//$'\eP'(|*[^$'\e'])($'\e\e')#$'\e\\'} 
			unexpected=${(S)unexpected//$'\e'[^$'\a\e']#($'\a'|$'\e\\')} 
			unexpected=${${unexpected//$'\033[1;32mShell integration activated\033[0m\n'}//$'\r'} 
			typeset -g P9K_STARTUP_CONSOLE_OUTPUT=("$content" "$unexpected") 
			if [[ -n $unexpected ]]
			then
				local omz1='[Oh My Zsh] Would you like to update? [Y/n]: ' 
				local omz2='Updating Oh My Zsh' 
				local omz3='https://shop.planetargon.com/collections/oh-my-zsh' 
				local omz4='There was an error updating. Try again later?' 
				if [[ $unexpected != ($omz1|)$omz2*($omz3|$omz4)[^$'\n']#($'\n'|) ]]
				then
					echo -E - ""
					echo -E - "${(%):-[%3FWARNING%f]: Console output during zsh initialization detected.}"
					echo -E - ""
					echo -E - "${(%):-When using Powerlevel10k with instant prompt, console output during zsh}"
					echo -E - "${(%):-initialization may indicate issues.}"
					echo -E - ""
					echo -E - "${(%):-You can:}"
					echo -E - ""
					echo -E - "${(%):-  - %BRecommended%b: Change %B$__p9k_zshrc_u%b so that it does not perform console I/O}"
					echo -E - "${(%):-    after the instant prompt preamble. See the link below for details.}"
					echo -E - ""
					echo -E - "${(%):-    * You %Bwill not%b see this error message again.}"
					echo -E - "${(%):-    * Zsh will start %Bquickly%b and prompt will update %Bsmoothly%b.}"
					echo -E - ""
					echo -E - "${(%):-  - Suppress this warning either by running %Bp10k configure%b or by manually}"
					echo -E - "${(%):-    defining the following parameter:}"
					echo -E - ""
					echo -E - "${(%):-      %3Ftypeset%f -g POWERLEVEL9K_INSTANT_PROMPT=quiet}"
					echo -E - ""
					echo -E - "${(%):-    * You %Bwill not%b see this error message again.}"
					echo -E - "${(%):-    * Zsh will start %Bquickly%b but prompt will %Bjump down%b after initialization.}"
					echo -E - ""
					echo -E - "${(%):-  - Disable instant prompt either by running %Bp10k configure%b or by manually}"
					echo -E - "${(%):-    defining the following parameter:}"
					echo -E - ""
					echo -E - "${(%):-      %3Ftypeset%f -g POWERLEVEL9K_INSTANT_PROMPT=off}"
					echo -E - ""
					echo -E - "${(%):-    * You %Bwill not%b see this error message again.}"
					echo -E - "${(%):-    * Zsh will start %Bslowly%b.}"
					echo -E - ""
					echo -E - "${(%):-  - Do nothing.}"
					echo -E - ""
					echo -E - "${(%):-    * You %Bwill%b see this error message every time you start zsh.}"
					echo -E - "${(%):-    * Zsh will start %Bquickly%b but prompt will %Bjump down%b after initialization.}"
					echo -E - ""
					echo -E - "${(%):-For details, see:}"
					if (( _p9k_term_has_href ))
					then
						echo - "${(%):-\e]8;;https://github.com/romkatv/powerlevel10k#instant-prompt\ahttps://github.com/romkatv/powerlevel10k#instant-prompt\e]8;;\a}"
					else
						echo - "${(%):-https://github.com/romkatv/powerlevel10k#instant-prompt}"
					fi
					echo -E - ""
					echo - "${(%):-%3F-- console output produced during zsh initialization follows --%f}"
					echo -E - ""
				fi
			fi
			command cat -- $__p9k_instant_prompt_output
			echo -nE - $sp
			zf_rm -f -- $__p9k_instant_prompt_output
		} 2> /dev/null
	else
		zf_rm -f -- $__p9k_instant_prompt_output 2> /dev/null
		if (( _z4h_can_save_restore_screen == 1 && __p9k_instant_prompt_sourced >= 35 ))
		then
			-z4h-restore-screen
			unset _z4h_saved_screen
		fi
		print -rn -- $terminfo[rc]${(%):-%b%k%f%s%u}$terminfo[ed]
	fi
	prompt_opts=(percent subst sp cr) 
	if [[ $_POWERLEVEL9K_DISABLE_INSTANT_PROMPT == 0 && $__p9k_instant_prompt_active == 2 ]]
	then
		echo -E - "" >&2
		echo -E - "${(%):-[%1FERROR%f]: When using Powerlevel10k with instant prompt, %Bprompt_cr%b must be unset.}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-You can:}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-  - %BRecommended%b: call %Bp10k finalize%b at the end of %B$__p9k_zshrc_u%b.}" >&2
		echo -E - "${(%):-    You can do this by running the following command:}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-      %2Fecho%f %3F'(( ! \${+functions[p10k]\} )) || p10k finalize'%f >>! $__p9k_zshrc_u}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-    * You %Bwill not%b see this error message again.}" >&2
		echo -E - "${(%):-    * Zsh will start %Bquickly%b and %Bwithout%b prompt flickering.}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-  - Find where %Bprompt_cr%b option gets sets in your zsh configs and stop setting it.}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-    * You %Bwill not%b see this error message again.}" >&2
		echo -E - "${(%):-    * Zsh will start %Bquickly%b and %Bwithout%b prompt flickering.}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-  - Disable instant prompt either by running %Bp10k configure%b or by manually}" >&2
		echo -E - "${(%):-    defining the following parameter:}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-      %3Ftypeset%f -g POWERLEVEL9K_INSTANT_PROMPT=off}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-    * You %Bwill not%b see this error message again.}" >&2
		echo -E - "${(%):-    * Zsh will start %Bslowly%b.}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-  - Do nothing.}" >&2
		echo -E - "" >&2
		echo -E - "${(%):-    * You %Bwill%b see this error message every time you start zsh.}" >&2
		echo -E - "${(%):-    * Zsh will start %Bquckly%b but %Bwith%b prompt flickering.}" >&2
		echo -E - "" >&2
	fi
}
_p9k_color () {
	local key="_p9k_color ${(pj:\0:)*}" 
	_p9k__ret=$_p9k_cache[$key] 
	if [[ -n $_p9k__ret ]]
	then
		_p9k__ret[-1,-1]='' 
	else
		_p9k_param "$@"
		_p9k_translate_color $_p9k__ret
		_p9k_cache[$key]=${_p9k__ret}. 
	fi
}
_p9k_custom_prompt () {
	local segment_name=${1:u} 
	local command=_POWERLEVEL9K_CUSTOM_${segment_name} 
	command=${(P)command} 
	local parts=("${(@z)command}") 
	local cmd="${(Q)parts[1]}" 
	(( $+functions[$cmd] || $+commands[$cmd] )) || return
	local content="$(eval $command)" 
	[[ -n $content ]] || return
	_p9k_prompt_segment "prompt_custom_$1" $_p9k_color2 $_p9k_color1 "CUSTOM_${segment_name}_ICON" 0 '' "$content"
}
_p9k_declare () {
	local -i set=$+parameters[$2] 
	(( ARGC > 2 || set )) || return 0
	case $1 in
		(-b) if (( set ))
			then
				[[ ${(P)2} == true ]] && typeset -gi _$2=1 || typeset -gi _$2=0
			else
				typeset -gi _$2=$3
			fi ;;
		(-a) local -a v=("${(@P)2}") 
			if (( set ))
			then
				eval "typeset -ga _${(q)2}=(${(@qq)v})"
			else
				if [[ $3 != '--' ]]
				then
					echo "internal error in _p9k_declare " "${(qqq)@}" >&2
				fi
				eval "typeset -ga _${(q)2}=(${(@qq)*[4,-1]})"
			fi ;;
		(-i) (( set )) && typeset -gi _$2=$2 || typeset -gi _$2=$3 ;;
		(-F) (( set )) && typeset -gF _$2=$2 || typeset -gF _$2=$3 ;;
		(-s) (( set )) && typeset -g _$2=${(P)2} || typeset -g _$2=$3 ;;
		(-e) if (( set ))
			then
				local v=${(P)2} 
				typeset -g _$2=${(g::)v}
			else
				typeset -g _$2=${(g::)3}
			fi ;;
		(*) echo "internal error in _p9k_declare " "${(qqq)@}" >&2 ;;
	esac
}
_p9k_deinit () {
	(( $+functions[_p9k_preinit] )) && unfunction _p9k_preinit
	(( $+functions[gitstatus_stop_p9k_] )) && gitstatus_stop_p9k_ POWERLEVEL9K
	_p9k_worker_stop
	if (( _p9k__state_dump_fd ))
	then
		zle -F $_p9k__state_dump_fd
		exec {_p9k__state_dump_fd}>&-
	fi
	if (( _p9k__restore_prompt_fd ))
	then
		zle -F $_p9k__restore_prompt_fd
		exec {_p9k__restore_prompt_fd}>&-
	fi
	if (( _p9k__redraw_fd ))
	then
		zle -F $_p9k__redraw_fd
		exec {_p9k__redraw_fd}>&-
	fi
	(( $+_p9k__iterm2_precmd )) && functions[iterm2_precmd]=$_p9k__iterm2_precmd 
	(( $+_p9k__iterm2_decorate_prompt )) && functions[iterm2_decorate_prompt]=$_p9k__iterm2_decorate_prompt 
	unset -m '(_POWERLEVEL9K_|P9K_|_p9k_)*~(P9K_SSH|_P9K_SSH_TTY|P9K_TOOLBOX_NAME|P9K_TTY|_P9K_TTY)'
	[[ -n $__p9k_locale ]] || unset __p9k_locale
}
_p9k_delete_instant_prompt () {
	local user=${(%):-%n} 
	local root_dir=${__p9k_dump_file:h} 
	zf_rm -f -- $root_dir/p10k-instant-prompt-$user.zsh{,.zwc} ${root_dir}/p10k-$user/prompt-*(N) 2> /dev/null
}
_p9k_deschedule_redraw () {
	(( _p9k__redraw_fd )) || return
	zle -F $_p9k__redraw_fd
	exec {_p9k__redraw_fd}>&-
	_p9k__redraw_fd=0 
}
_p9k_display_segment () {
	[[ $_p9k__display_v[$1] == $3 ]] && return
	_p9k__display_v[$1]=$3 
	[[ $3 == hide ]] && typeset -g $2= || unset $2
	__p9k_reset_state=2 
}
_p9k_do_dump () {
	eval "$__p9k_intro"
	zle -F $1
	exec {1}>&-
	(( _p9k__state_dump_fd )) || return
	if (( ! _p9k__instant_prompt_disabled ))
	then
		_p9k__instant_prompt_sig=$_p9k__cwd:$P9K_SSH:${(%):-%#} 
		_p9k_set_instant_prompt
		_p9k_dump_instant_prompt
		_p9k_dumped_instant_prompt_sigs[$_p9k__instant_prompt_sig]=1 
	fi
	_p9k_dump_state
	_p9k__state_dump_scheduled=0 
	_p9k__state_dump_fd=0 
}
_p9k_do_nothing () {
	true
}
_p9k_dump_instant_prompt () {
	local user=${(%):-%n} 
	local root_dir=${__p9k_dump_file:h} 
	local prompt_dir=${root_dir}/p10k-$user 
	local root_file=$root_dir/p10k-instant-prompt-$user.zsh 
	local prompt_file=$prompt_dir/prompt-${#_p9k__cwd} 
	[[ -d $prompt_dir ]] || mkdir -p $prompt_dir || return
	[[ -w $root_dir && -w $prompt_dir ]] || return
	if [[ ! -e $root_file ]]
	then
		local tmp=$root_file.tmp.$$ 
		local -i fd
		sysopen -a -m 600 -o creat,trunc -u fd -- $tmp || return
		{
			[[ $TERM == (screen*|tmux*) ]] && local screen='-n'  || local screen='-z' 
			local -a display_v=("${_p9k__display_v[@]}") 
			local -i i
			for ((i = 6; i <= $#display_v; i+=2)) do
				display_v[i]=show 
			done
			display_v[2]=hide 
			display_v[4]=hide 
			local gitstatus_dir=${${_POWERLEVEL9K_GITSTATUS_DIR:A}:-${__p9k_root_dir}/gitstatus} 
			local gitstatus_header
			if [[ -r $gitstatus_dir/install.info ]]
			then
				IFS= read -r gitstatus_header < $gitstatus_dir/install.info || return
			fi
			print -r -- '[[ -t 0 && -t 1 && -t 2 && -o interactive && -o zle && -o no_xtrace ]] &&
  ! (( ${+__p9k_instant_prompt_disabled} || ZSH_SUBSHELL || ${+ZSH_SCRIPT} || ${+ZSH_EXECUTION_STRING} )) || return 0' >&$fd
			print -r -- "() {
  $__p9k_intro_no_locale
  typeset -gi __p9k_instant_prompt_disabled=1
  [[ \$ZSH_VERSION == ${(q)ZSH_VERSION} && \$ZSH_PATCHLEVEL == ${(q)ZSH_PATCHLEVEL} &&
     $screen \${(M)TERM:#(screen*|tmux*)} &&
     \${#\${(M)VTE_VERSION:#(<1-4602>|4801)}} == "${#${(M)VTE_VERSION:#(<1-4602>|4801)}}" &&
     \$POWERLEVEL9K_DISABLE_INSTANT_PROMPT != 'true' &&
     \$POWERLEVEL9K_INSTANT_PROMPT != 'off' ]] || return
  typeset -g __p9k_instant_prompt_param_sig=${(q+)_p9k__param_sig}
  local gitstatus_dir=${(q)gitstatus_dir}
  local gitstatus_header=${(q)gitstatus_header}
  local -i ZLE_RPROMPT_INDENT=${ZLE_RPROMPT_INDENT:-1}
  local PROMPT_EOL_MARK=${(q)PROMPT_EOL_MARK-%B%S%#%s%b}
  [[ -n \$SSH_CLIENT || -n \$SSH_TTY || -n \$SSH_CONNECTION ]] && local ssh=1 || local ssh=0
  local cr=\$'\r' lf=\$'\n' esc=\$'\e[' rs=$'\x1e' us=$'\x1f'
  local -i height=${_POWERLEVEL9K_INSTANT_PROMPT_COMMAND_LINES-1}
  local prompt_dir=${(q)prompt_dir}" >&$fd
			if (( ! ${+_POWERLEVEL9K_INSTANT_PROMPT_COMMAND_LINES} ))
			then
				print -r -- '
  (( _z4h_can_save_restore_screen == 1 )) && height=0' >&$fd
			fi
			print -r -- '
  local real_gitstatus_header
  if [[ -r $gitstatus_dir/install.info ]]; then
    IFS= read -r real_gitstatus_header <$gitstatus_dir/install.info || real_gitstatus_header=borked
  fi
  [[ $real_gitstatus_header == $gitstatus_header ]] || return
  zmodload zsh/langinfo zsh/terminfo zsh/system || return
  if [[ $langinfo[CODESET] != (utf|UTF)(-|)8 ]]; then
    local loc_cmd=$commands[locale]
    [[ -z $loc_cmd ]] && loc_cmd='${(q)commands[locale]}'
    if [[ -x $loc_cmd ]]; then
      local -a locs
      if locs=(${(@M)$(locale -a 2>/dev/null):#*.(utf|UTF)(-|)8}) && (( $#locs )); then
        local loc=${locs[(r)(#i)C.UTF(-|)8]:-${locs[(r)(#i)en_US.UTF(-|)8]:-$locs[1]}}
        [[ -n $LC_ALL ]] && local LC_ALL=$loc || local LC_CTYPE=$loc
      fi
    fi
  fi
  (( terminfo[colors] == '${terminfo[colors]:-0}' )) || return
  (( $+terminfo[cuu] && $+terminfo[cuf] && $+terminfo[ed] && $+terminfo[sc] && $+terminfo[rc] )) || return
  local pwd=${(%):-%/}
  [[ $pwd == /* ]] || return
  local prompt_file=$prompt_dir/prompt-${#pwd}
  local key=$pwd:$ssh:${(%):-%#}
  local content
  if [[ ! -e $prompt_file ]]; then
    typeset -gi __p9k_instant_prompt_sourced='$__p9k_instant_prompt_version'
    return 1
  fi
  { content="$(<$prompt_file)" } 2>/dev/null || return
  local tail=${content##*$rs$key$us}
  if (( ${#tail} == ${#content} )); then
    typeset -gi __p9k_instant_prompt_sourced='$__p9k_instant_prompt_version'
    return 1
  fi
  local _p9k__ipe
  local P9K_PROMPT=instant
  if [[ -z $P9K_TTY || $P9K_TTY == old && -n ${_P9K_TTY:#$TTY} ]]; then' >&$fd
			if (( _POWERLEVEL9K_NEW_TTY_MAX_AGE_SECONDS < 0 ))
			then
				print -r -- '    typeset -gx P9K_TTY=new' >&$fd
			else
				print -r -- '
    typeset -gx P9K_TTY=old
    zmodload -F zsh/stat b:zstat || return
    zmodload zsh/datetime || return
    local -a stat
    if zstat -A stat +ctime -- $TTY 2>/dev/null &&
      (( EPOCHREALTIME - stat[1] < '$_POWERLEVEL9K_NEW_TTY_MAX_AGE_SECONDS' )); then
      P9K_TTY=new
    fi' >&$fd
			fi
			print -r -- '  fi
  typeset -gx _P9K_TTY=$TTY
  local -i _p9k__empty_line_i=3 _p9k__ruler_i=3
  local -A _p9k_display_k=('${(j: :)${(@q)${(kv)_p9k_display_k}}}')
  local -a _p9k__display_v=('${(j: :)${(@q)display_v}}')
  function p10k() {
    '$__p9k_intro'
    [[ $1 == display ]] || return
    shift
    local -i k dump
    local opt prev new pair list name var
    while getopts ":ha" opt; do
      case $opt in
        a) dump=1;;
        h) return 0;;
        ?) return 1;;
      esac
    done
    if (( dump )); then
      reply=()
      shift $((OPTIND-1))
      (( ARGC )) || set -- "*"
      for opt; do
        for k in ${(u@)_p9k_display_k[(I)$opt]:/(#m)*/$_p9k_display_k[$MATCH]}; do
          reply+=($_p9k__display_v[k,k+1])
        done
      done
      return 0
    fi
    for opt in "${@:$OPTIND}"; do
      pair=(${(s:=:)opt})
      list=(${(s:,:)${pair[2]}})
      if [[ ${(b)pair[1]} == $pair[1] ]]; then
        local ks=($_p9k_display_k[$pair[1]])
      else
        local ks=(${(u@)_p9k_display_k[(I)$pair[1]]:/(#m)*/$_p9k_display_k[$MATCH]})
      fi
      for k in $ks; do
        if (( $#list == 1 )); then
          [[ $_p9k__display_v[k+1] == $list[1] ]] && continue
          new=$list[1]
        else
          new=${list[list[(I)$_p9k__display_v[k+1]]+1]:-$list[1]}
          [[ $_p9k__display_v[k+1] == $new ]] && continue
        fi
        _p9k__display_v[k+1]=$new
        name=$_p9k__display_v[k]
        if [[ $name == (empty_line|ruler) ]]; then
          var=_p9k__${name}_i
          [[ $new == hide ]] && typeset -gi $var=3 || unset $var
        elif [[ $name == (#b)(<->)(*) ]]; then
          var=_p9k__${match[1]}${${${${match[2]//\/}/#left/l}/#right/r}/#gap/g}
          [[ $new == hide ]] && typeset -g $var= || unset $var
        fi
      done
    done
  }' >&$fd
			if (( _POWERLEVEL9K_PROMPT_ADD_NEWLINE ))
			then
				print -r -- '  [[ $P9K_TTY == old ]] && { unset _p9k__empty_line_i; _p9k__display_v[2]=print }' >&$fd
			fi
			if (( _POWERLEVEL9K_SHOW_RULER ))
			then
				print -r -- '[[ $P9K_TTY == old ]] && { unset _p9k__ruler_i; _p9k__display_v[4]=print }' >&$fd
			fi
			if (( $+functions[p10k-on-init] ))
			then
				print -r -- '
  p10k-on-init() { '$functions[p10k-on-init]' }' >&$fd
			fi
			if (( $+functions[p10k-on-pre-prompt] ))
			then
				print -r -- '
  p10k-on-pre-prompt() { '$functions[p10k-on-pre-prompt]' }' >&$fd
			fi
			if (( $+functions[p10k-on-post-prompt] ))
			then
				print -r -- '
  p10k-on-post-prompt() { '$functions[p10k-on-post-prompt]' }' >&$fd
			fi
			if (( $+functions[p10k-on-post-widget] ))
			then
				print -r -- '
  p10k-on-post-widget() { '$functions[p10k-on-post-widget]' }' >&$fd
			fi
			if (( $+functions[p10k-on-init] ))
			then
				print -r -- '
  p10k-on-init' >&$fd
			fi
			local pat idx var
			for pat idx var in $_p9k_show_on_command
			do
				print -r -- "
  local $var=
  _p9k__display_v[$idx]=hide" >&$fd
			done
			if (( $+functions[p10k-on-pre-prompt] ))
			then
				print -r -- '
  p10k-on-pre-prompt' >&$fd
			fi
			if (( $+functions[p10k-on-init] ))
			then
				print -r -- '
  unfunction p10k-on-init' >&$fd
			fi
			if (( $+functions[p10k-on-pre-prompt] ))
			then
				print -r -- '
  unfunction p10k-on-pre-prompt' >&$fd
			fi
			if (( $+functions[p10k-on-post-prompt] ))
			then
				print -r -- '
  unfunction p10k-on-post-prompt' >&$fd
			fi
			if (( $+functions[p10k-on-post-widget] ))
			then
				print -r -- '
  unfunction p10k-on-post-widget' >&$fd
			fi
			print -r -- '
  () {
'$functions[_p9k_init_toolbox]'
  }
  trap "unset -m _p9k__\*; unfunction p10k" EXIT
  local -a _p9k_t=("${(@ps:$us:)${tail%%$rs*}}")
  if [[ $+VTE_VERSION == 1 || $TERM_PROGRAM == Hyper ]] && (( $+commands[stty] )); then
    if [[ $TERM_PROGRAM == Hyper ]]; then
      local bad_lines=40 bad_columns=100
    else
      local bad_lines=24 bad_columns=80
    fi
    if (( LINES == bad_lines && COLUMNS == bad_columns )); then
      zmodload -F zsh/stat b:zstat || return
      zmodload zsh/datetime || return
      local -a tty_ctime
      if ! zstat -A tty_ctime +ctime -- $TTY 2>/dev/null || (( tty_ctime[1] + 2 > EPOCHREALTIME )); then
        local -F deadline=$((EPOCHREALTIME+0.025))
        local tty_size
        while true; do
          if (( EPOCHREALTIME > deadline )) || ! tty_size="$(command stty size 2>/dev/null)" || [[ $tty_size != <->" "<-> ]]; then
            (( $+_p9k__ruler_i )) || local -i _p9k__ruler_i=1
            local _p9k__g= _p9k__'$#_p9k_line_segments_right'r= _p9k__'$#_p9k_line_segments_right'r_frame=
            break
          fi
          if [[ $tty_size != "$bad_lines $bad_columns" ]]; then
            local lines_columns=(${=tty_size})
            local LINES=$lines_columns[1]
            local COLUMNS=$lines_columns[2]
            break
          fi
        done
      fi
    fi
  fi' >&$fd
			(( __p9k_ksh_arrays )) && print -r -- '  setopt ksh_arrays' >&$fd
			(( __p9k_sh_glob )) && print -r -- '  setopt sh_glob' >&$fd
			print -r -- '  typeset -ga __p9k_used_instant_prompt=("${(@e)_p9k_t[-3,-1]}")' >&$fd
			(( __p9k_ksh_arrays )) && print -r -- '  unsetopt ksh_arrays' >&$fd
			(( __p9k_sh_glob )) && print -r -- '  unsetopt sh_glob' >&$fd
			print -r -- '
  local -i prompt_height=${#${__p9k_used_instant_prompt[1]//[^$lf]}}
  (( height += prompt_height ))
  local _p9k__ret
  function _p9k_prompt_length() {
    local -i COLUMNS=1024
    local -i x y=${#1} m
    if (( y )); then
      while (( ${${(%):-$1%$y(l.1.0)}[-1]} )); do
        x=y
        (( y *= 2 ))
      done
      while (( y > x + 1 )); do
        (( m = x + (y - x) / 2 ))
        (( ${${(%):-$1%$m(l.x.y)}[-1]} = m ))
      done
    fi
    typeset -g _p9k__ret=$x
  }
  local out=${(%):-%b%k%f%s%u}
  if [[ $P9K_TTY == old && ( $+VTE_VERSION == 0 && $TERM_PROGRAM != Hyper || $+_p9k__g == 0 ) ]]; then
    local mark=${(e)PROMPT_EOL_MARK}
    [[ $mark == "%B%S%#%s%b" ]] && _p9k__ret=1 || _p9k_prompt_length $mark
    local -i fill=$((COLUMNS > _p9k__ret ? COLUMNS - _p9k__ret : 0))
    out+="${(%):-$mark${(pl.$fill.. .)}$cr%b%k%f%s%u%E}"
  else
    out+="${(%):-$cr%E}"
  fi
  if (( _z4h_can_save_restore_screen != 1 )); then
    (( height )) && out+="${(pl.$height..$lf.)}$esc${height}A"
    out+="$terminfo[sc]"
  fi
  out+=${(%):-"$__p9k_used_instant_prompt[1]$__p9k_used_instant_prompt[2]"}
  if [[ -n $__p9k_used_instant_prompt[3] ]]; then
    _p9k_prompt_length "$__p9k_used_instant_prompt[2]"
    local -i left_len=_p9k__ret
    _p9k_prompt_length "$__p9k_used_instant_prompt[3]"
    if (( _p9k__ret )); then
      local -i gap=$((COLUMNS - left_len - _p9k__ret - ZLE_RPROMPT_INDENT))
      if (( gap >= 40 )); then
        out+="${(pl.$gap.. .)}${(%):-${__p9k_used_instant_prompt[3]}%b%k%f%s%u}$cr$esc${left_len}C"
      fi
    fi
  fi
  if (( _z4h_can_save_restore_screen == 1 )); then
    if (( height )); then
      out+="$cr${(pl:$((height-prompt_height))::\n:)}$esc${height}A$terminfo[sc]$out"
    else
      out+="$cr${(pl:$((height-prompt_height))::\n:)}$terminfo[sc]$out"
    fi
  fi
  if [[ -n "$TMPDIR" && ( ( -d "$TMPDIR" && -w "$TMPDIR" ) || ! ( -d /tmp && -w /tmp ) ) ]]; then
    local tmpdir=$TMPDIR
  else
    local tmpdir=/tmp
  fi
  typeset -g __p9k_instant_prompt_output=$tmpdir/p10k-instant-prompt-output-${(%):-%n}-$$
  { : > $__p9k_instant_prompt_output } || return
  print -rn -- "${out}${esc}?2004h" || return
  if (( $+commands[stty] )); then
    command stty -icanon 2>/dev/null
  fi
  local fd_null
  sysopen -ru fd_null /dev/null || return
  exec {__p9k_fd_0}<&0 {__p9k_fd_1}>&1 {__p9k_fd_2}>&2 0<&$fd_null 1>$__p9k_instant_prompt_output
  exec 2>&1 {fd_null}>&-
  typeset -gi __p9k_instant_prompt_active=1
  if (( _z4h_can_save_restore_screen == 1 )); then
    typeset -g _z4h_saved_screen
    -z4h-save-screen
  fi
  typeset -g __p9k_instant_prompt_dump_file=${XDG_CACHE_HOME:-~/.cache}/p10k-dump-${(%):-%n}.zsh
  if builtin source $__p9k_instant_prompt_dump_file 2>/dev/null && (( $+functions[_p9k_preinit] )); then
    _p9k_preinit
  fi
  function _p9k_instant_prompt_cleanup() {
    (( ZSH_SUBSHELL == 0 && ${+__p9k_instant_prompt_active} )) || return 0
    '$__p9k_intro_no_locale'
    unset __p9k_instant_prompt_active
    exec 0<&$__p9k_fd_0 1>&$__p9k_fd_1 2>&$__p9k_fd_2 {__p9k_fd_0}>&- {__p9k_fd_1}>&- {__p9k_fd_2}>&-
    unset __p9k_fd_0 __p9k_fd_1 __p9k_fd_2
    typeset -gi __p9k_instant_prompt_erased=1
    if (( _z4h_can_save_restore_screen == 1 && __p9k_instant_prompt_sourced >= 35 )); then
      -z4h-restore-screen
      unset _z4h_saved_screen
    fi
    print -rn -- $terminfo[rc]${(%):-%b%k%f%s%u}$terminfo[ed]
    if [[ -s $__p9k_instant_prompt_output ]]; then
      command cat $__p9k_instant_prompt_output 2>/dev/null
      if (( $1 )); then
        local _p9k__ret mark="${(e)${PROMPT_EOL_MARK-%B%S%#%s%b}}"
        _p9k_prompt_length $mark
        local -i fill=$((COLUMNS > _p9k__ret ? COLUMNS - _p9k__ret : 0))
        echo -nE - "${(%):-%b%k%f%s%u$mark${(pl.$fill.. .)}$cr%b%k%f%s%u%E}"
      fi
    fi
    zshexit_functions=(${zshexit_functions:#_p9k_instant_prompt_cleanup})
    zmodload -F zsh/files b:zf_rm || return
    local user=${(%):-%n}
    local root_dir=${__p9k_instant_prompt_dump_file:h}
    zf_rm -f -- $__p9k_instant_prompt_output $__p9k_instant_prompt_dump_file{,.zwc} $root_dir/p10k-instant-prompt-$user.zsh{,.zwc} $root_dir/p10k-$user/prompt-*(N) 2>/dev/null
  }
  function _p9k_instant_prompt_precmd_first() {
    '$__p9k_intro'
    function _p9k_instant_prompt_sched_last() {
      (( ${+__p9k_instant_prompt_active} )) || return 0
      _p9k_instant_prompt_cleanup 1
      setopt no_local_options prompt_cr prompt_sp
    }
    zmodload zsh/sched
    sched +0 _p9k_instant_prompt_sched_last
    precmd_functions=(${(@)precmd_functions:#_p9k_instant_prompt_precmd_first})
  }
  zshexit_functions=(_p9k_instant_prompt_cleanup $zshexit_functions)
  precmd_functions=(_p9k_instant_prompt_precmd_first $precmd_functions)
  DISABLE_UPDATE_PROMPT=true
} && unsetopt prompt_cr prompt_sp && typeset -gi __p9k_instant_prompt_sourced='$__p9k_instant_prompt_version' ||
  typeset -gi __p9k_instant_prompt_sourced=${__p9k_instant_prompt_sourced:-0}' >&$fd
		} always {
			exec {fd}>&-
		}
		{
			(( ! $? )) || return
			zf_rm -f -- $root_file.zwc || return
			zf_mv -f -- $tmp $root_file || return
			zcompile -R -- $tmp.zwc $root_file || return
			zf_mv -f -- $tmp.zwc $root_file.zwc || return
		} always {
			(( $? )) && zf_rm -f -- $tmp $tmp.zwc 2> /dev/null
		}
	fi
	local tmp=$prompt_file.tmp.$$ 
	zf_mv -f -- $prompt_file $tmp 2> /dev/null
	if [[ "$(<$tmp)" == *$'\x1e'$_p9k__instant_prompt_sig$'\x1f'* ]] 2> /dev/null
	then
		echo -n > $tmp || return
	fi
	local -i fd
	sysopen -a -m 600 -o creat -u fd -- $tmp || return
	{
		{
			print -rnu $fd -- $'\x1e'$_p9k__instant_prompt_sig$'\x1f'${(pj:\x1f:)_p9k_t}$'\x1f'$_p9k__instant_prompt || return
		} always {
			exec {fd}>&-
		}
		zf_mv -f -- $tmp $prompt_file || return
	} always {
		(( $? )) && zf_rm -f -- $tmp 2> /dev/null
	}
}
_p9k_dump_state () {
	local dir=${__p9k_dump_file:h} 
	[[ -d $dir ]] || mkdir -p -- $dir || return
	[[ -w $dir ]] || return
	local tmp=$__p9k_dump_file.tmp.$$ 
	local -i fd
	sysopen -a -m 600 -o creat,trunc -u fd -- $tmp || return
	{
		{
			typeset -g __p9k_cached_param_pat=$_p9k__param_pat 
			typeset -g __p9k_cached_param_sig=$_p9k__param_sig 
			typeset -pm __p9k_cached_param_pat __p9k_cached_param_sig >&$fd || return
			unset __p9k_cached_param_pat __p9k_cached_param_sig
			(( $+_p9k_preinit )) && {
				print -r -- $_p9k_preinit >&$fd || return
			}
			print -r -- '_p9k_restore_state_impl() {' >&$fd || return
			typeset -pm '_POWERLEVEL9K_*|_p9k_[^_]*|icons' >&$fd || return
			print -r -- '}' >&$fd || return
		} always {
			exec {fd}>&-
		}
		zf_rm -f -- $__p9k_dump_file.zwc || return
		zf_mv -f -- $tmp $__p9k_dump_file || return
		zcompile -R -- $tmp.zwc $__p9k_dump_file || return
		zf_mv -f -- $tmp.zwc $__p9k_dump_file.zwc || return
	} always {
		(( $? )) && zf_rm -f -- $tmp $tmp.zwc 2> /dev/null
	}
}
_p9k_escape () {
	[[ $1 == *["~!#\`\$^&*()\\\"'<>?{}[]"]* ]] && _p9k__ret="\${(Q)\${:-${(qqq)${(q)1}}}}"  || _p9k__ret=$1 
}
_p9k_escape_style () {
	[[ $1 == *'}'* ]] && _p9k__ret='${:-"'$1'"}'  || _p9k__ret=$1 
}
_p9k_fetch_cwd () {
	if [[ $PWD == /* && $PWD -ef . ]]
	then
		_p9k__cwd=$PWD 
	else
		_p9k__cwd=${${${:-.}:a}:-.} 
	fi
	_p9k__cwd_a=${${_p9k__cwd:A}:-.} 
	case $_p9k__cwd in
		(/ | .) _p9k__parent_dirs=() 
			_p9k__parent_mtimes=() 
			_p9k__parent_mtimes_i=() 
			_p9k__parent_mtimes_s= 
			return ;;
		(~ | ~/*) local parent=${${${:-~/..}:a}%/}/ 
			local parts=(${(s./.)_p9k__cwd#$parent})  ;;
		(*) local parent=/ 
			local parts=(${(s./.)_p9k__cwd})  ;;
	esac
	local MATCH
	_p9k__parent_dirs=(${(@)${:-{$#parts..1}}/(#m)*/$parent${(pj./.)parts[1,MATCH]}}) 
	if ! zstat -A _p9k__parent_mtimes +mtime -- $_p9k__parent_dirs 2> /dev/null
	then
		_p9k__parent_mtimes=(${(@)parts/*/-1}) 
	fi
	_p9k__parent_mtimes_i=(${(@)${:-{1..$#parts}}/(#m)*/$MATCH:$_p9k__parent_mtimes[MATCH]}) 
	_p9k__parent_mtimes_s="$_p9k__parent_mtimes_i" 
}
_p9k_fetch_nordvpn_status () {
	setopt err_return no_multi_byte
	local REPLY
	zsocket /run/nordvpn/nordvpnd.sock
	local -i fd=REPLY 
	{
		print -nu $fd 'PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n\0\0\0\4\1\0\0\0\0\0\0;\1\4\0\0\0\1\203\206E\213b\270\327\2762\322z\230\326j\246A\206\240\344\35\23\235\t_\213\35u\320b\r&=LMedz\212\232\312\310\264\307`+\262\332\340@\2te\206M\2035\5\261\37\0\0\5\0\1\0\0\0\1\0\0\0\0\0\0\0\25\1\4\0\0\0\3\203\206E\215b\270\327\2762\322z\230\334\221\246\324\177\302\301\300\277\0\0\5\0\1\0\0\0\3\0\0\0\0\0'
		local val
		local -i len n wire tag
		{
			IFS='' read -t 0.25 -r val
			val=$'\n' 
			while true
			do
				tag=$((#val)) 
				wire='tag & 7' 
				(( (tag >>= 3) && tag <= $#__p9k_nordvpn_tag )) || break
				if (( wire == 0 ))
				then
					sysread -s 1 -t 0.25 val
					n=$((#val)) 
					(( n < 128 )) || break
					if (( tag == 2 ))
					then
						case $n in
							(1) typeset -g P9K_NORDVPN_TECHNOLOGY=OPENVPN  ;;
							(2) typeset -g P9K_NORDVPN_TECHNOLOGY=NORDLYNX  ;;
							(3) typeset -g P9K_NORDVPN_TECHNOLOGY=SKYLARK  ;;
							(*) typeset -g P9K_NORDVPN_TECHNOLOGY=UNKNOWN  ;;
						esac
					elif (( tag == 3 ))
					then
						case $n in
							(1) typeset -g P9K_NORDVPN_PROTOCOL=UDP  ;;
							(2) typeset -g P9K_NORDVPN_PROTOCOL=TCP  ;;
							(*) typeset -g P9K_NORDVPN_PROTOCOL=UNKNOWN  ;;
						esac
					else
						break
					fi
				else
					(( wire == 2 )) || break
					(( tag != 2 && tag != 3 )) || break
					[[ -t $fd ]] || true
					sysread -s 1 -t 0.25 val
					len=$((#val)) 
					val= 
					while (( $#val < len ))
					do
						[[ -t $fd ]] || true
						sysread -s $(( len - $#val )) -t 0.25 'val[$#val+1]'
					done
					typeset -g $__p9k_nordvpn_tag[tag]=$val
				fi
				[[ -t $fd ]] || true
				sysread -s 1 -t 0.25 val
			done
		} <&$fd
	} always {
		exec {fd}>&-
	}
}
_p9k_foreground () {
	[[ -n $1 ]] && _p9k__ret="%F{$1}"  || _p9k__ret="%f" 
}
_p9k_fvm_new () {
	_p9k_upglob .fvm/flutter_sdk @ && return 1
	local sdk=$_p9k__parent_dirs[$?]/.fvm/flutter_sdk 
	if [[ ${sdk:A} == (#b)*/versions/([^/]##) ]]
	then
		_p9k_prompt_segment prompt_fvm blue $_p9k_color1 FLUTTER_ICON 0 '' ${match[1]//\%/%%}
		return 0
	fi
	return 1
}
_p9k_fvm_old () {
	_p9k_upglob fvm @ && return 1
	local fvm=$_p9k__parent_dirs[$?]/fvm 
	if [[ ${fvm:A} == (#b)*/versions/([^/]##)/bin/flutter ]]
	then
		_p9k_prompt_segment prompt_fvm blue $_p9k_color1 FLUTTER_ICON 0 '' ${match[1]//\%/%%}
		return 0
	fi
	return 1
}
_p9k_gcloud_prefetch () {
	unset P9K_GCLOUD_CONFIGURATION P9K_GCLOUD_ACCOUNT P9K_GCLOUD_PROJECT P9K_GCLOUD_PROJECT_ID P9K_GCLOUD_PROJECT_NAME
	(( $+commands[gcloud] )) || return
	_p9k_read_word ${CLOUDSDK_CONFIG:-~/.config/gcloud}/active_config || return
	P9K_GCLOUD_CONFIGURATION=$_p9k__ret 
	if ! _p9k_cache_stat_get $0 ${CLOUDSDK_CONFIG:-~/.config/gcloud}/configurations/config_$P9K_GCLOUD_CONFIGURATION
	then
		local pair account project_id
		pair="$(gcloud config configurations describe $P9K_GCLOUD_CONFIGURATION \
      --format=$'value[separator="\1"](properties.core.account,properties.core.project)')" 
		(( ! $? )) && IFS=$'\1' read account project_id <<< $pair
		_p9k_cache_stat_set "$account" "$project_id"
	fi
	if [[ -n $_p9k__cache_val[1] ]]
	then
		P9K_GCLOUD_ACCOUNT=$_p9k__cache_val[1] 
	fi
	if [[ -n $_p9k__cache_val[2] ]]
	then
		P9K_GCLOUD_PROJECT_ID=$_p9k__cache_val[2] 
		P9K_GCLOUD_PROJECT=$P9K_GCLOUD_PROJECT_ID 
	fi
	if [[ $P9K_GCLOUD_CONFIGURATION == $_p9k_gcloud_configuration && $P9K_GCLOUD_ACCOUNT == $_p9k_gcloud_account && $P9K_GCLOUD_PROJECT_ID == $_p9k_gcloud_project_id ]]
	then
		[[ -n $_p9k_gcloud_project_name ]] && P9K_GCLOUD_PROJECT_NAME=$_p9k_gcloud_project_name 
		if (( _POWERLEVEL9K_GCLOUD_REFRESH_PROJECT_NAME_SECONDS < 0 ||
          _p9k__gcloud_last_fetch_ts + _POWERLEVEL9K_GCLOUD_REFRESH_PROJECT_NAME_SECONDS > EPOCHREALTIME ))
		then
			return
		fi
	else
		_p9k_gcloud_configuration=$P9K_GCLOUD_CONFIGURATION 
		_p9k_gcloud_account=$P9K_GCLOUD_ACCOUNT 
		_p9k_gcloud_project_id=$P9K_GCLOUD_PROJECT_ID 
		_p9k_gcloud_project_name= 
		_p9k__state_dump_scheduled=1 
	fi
	[[ -n $P9K_GCLOUD_CONFIGURATION && -n $P9K_GCLOUD_ACCOUNT && -n $P9K_GCLOUD_PROJECT_ID ]] || return
	_p9k__gcloud_last_fetch_ts=EPOCHREALTIME 
	_p9k_worker_invoke gcloud "_p9k_prompt_gcloud_compute ${(q)commands[gcloud]} ${(q)P9K_GCLOUD_CONFIGURATION} ${(q)P9K_GCLOUD_ACCOUNT} ${(q)P9K_GCLOUD_PROJECT_ID}"
}
_p9k_get_icon () {
	local key="_p9k_get_icon ${(pj:\0:)*}" 
	_p9k__ret=$_p9k_cache[$key] 
	if [[ -n $_p9k__ret ]]
	then
		_p9k__ret[-1,-1]='' 
	else
		if [[ $2 == $'\1'* ]]
		then
			_p9k__ret=${2[2,-1]} 
		else
			_p9k_param "$1" "$2" ${icons[$2]-$'\1'$3}
			if [[ $_p9k__ret == $'\1'* ]]
			then
				_p9k__ret=${_p9k__ret[2,-1]} 
			else
				_p9k__ret=${(g::)_p9k__ret} 
				[[ $_p9k__ret != $'\b'? ]] || _p9k__ret="%{$_p9k__ret%}" 
			fi
		fi
		_p9k_cache[$key]=${_p9k__ret}. 
	fi
}
_p9k_glob () {
	local dir=$_p9k__parent_dirs[$1] 
	local cached=$_p9k__glob_cache[$dir/$2] 
	if [[ $cached == $_p9k__parent_mtimes[$1]:* ]]
	then
		return ${cached##*:}
	fi
	local -a stat
	zstat -A stat +mtime -- $dir 2> /dev/null || stat=(-1) 
	eval 'local files=($dir/$~2('$3'N:t))'
	_p9k__glob_cache[$dir/$2]="$stat[1]:$#files" 
	return $#files
}
_p9k_goenv_global_version () {
	_p9k_read_pyenv_like_version_file ${GOENV_ROOT:-$HOME/.goenv}/version go- || _p9k__ret=system 
}
_p9k_haskell_stack_version () {
	if ! _p9k_cache_stat_get $0 $1 ${STACK_ROOT:-~/.stack}/{pantry/pantry.sqlite3,stack.sqlite3}
	then
		local v
		v="$(STACK_YAML=$1 stack \
      --silent                 \
      --no-install-ghc         \
      --skip-ghc-check         \
      --no-terminal            \
      --color=never            \
      --lock-file=read-only    \
      query compiler actual)"  || v= 
		_p9k_cache_stat_set "$v"
	fi
	_p9k__ret=$_p9k__cache_val[1] 
}
_p9k_human_readable_bytes () {
	typeset -F n=$1 
	local suf
	for suf in $__p9k_byte_suffix
	do
		(( n < 1024 )) && break
		(( n /= 1024 ))
	done
	if (( n >= 100 ))
	then
		printf -v _p9k__ret '%.0f.' $n
	elif (( n >= 10 ))
	then
		printf -v _p9k__ret '%.1f' $n
	else
		printf -v _p9k__ret '%.2f' $n
	fi
	_p9k__ret=${${_p9k__ret%%0#}%.}$suf 
}
_p9k_init () {
	_p9k_init_vars
	_p9k_restore_state || _p9k_init_cacheable
	typeset -g P9K_OS_ICON=$_p9k_os_icon 
	local -a _p9k__async_segments_compute
	local -i i
	local elem
	_p9k__prompt_side=left 
	_p9k__segment_index=1 
	for i in {1..$#_p9k_line_segments_left}
	do
		for elem in ${${(@0)_p9k_line_segments_left[i]}%_joined}
		do
			local f_init=_p9k_prompt_${elem}_init 
			(( $+functions[$f_init] )) && $f_init
			(( ++_p9k__segment_index ))
		done
	done
	_p9k__prompt_side=right 
	_p9k__segment_index=1 
	for i in {1..$#_p9k_line_segments_right}
	do
		for elem in ${${(@0)_p9k_line_segments_right[i]}%_joined}
		do
			local f_init=_p9k_prompt_${elem}_init 
			(( $+functions[$f_init] )) && $f_init
			(( ++_p9k__segment_index ))
		done
	done
	if [[ -n $_POWERLEVEL9K_PUBLIC_IP_VPN_INTERFACE || -n $_POWERLEVEL9K_IP_INTERFACE || -n $_POWERLEVEL9K_VPN_IP_INTERFACE ]]
	then
		_p9k_prompt_net_iface_init
	fi
	if [[ -n $_p9k__async_segments_compute ]]
	then
		functions[_p9k_async_segments_compute]=${(pj:\n:)_p9k__async_segments_compute} 
		_p9k_worker_start
	fi
	local k v
	for k v in ${(kv)_p9k_display_k}
	do
		[[ $k == -* ]] && continue
		_p9k__display_v[v]=$k 
		_p9k__display_v[v+1]=show 
	done
	_p9k__display_v[2]=hide 
	_p9k__display_v[4]=hide 
	if (( $+functions[iterm2_decorate_prompt] ))
	then
		_p9k__iterm2_decorate_prompt=$functions[iterm2_decorate_prompt] 
		iterm2_decorate_prompt () {
			typeset -g ITERM2_PRECMD_PS1=$PROMPT 
			typeset -g ITERM2_SHOULD_DECORATE_PROMPT= 
		}
	fi
	if (( $+functions[iterm2_precmd] ))
	then
		_p9k__iterm2_precmd=$functions[iterm2_precmd] 
		functions[iterm2_precmd]='local _p9k_status=$?; zle && return; () { return $_p9k_status; }; '$_p9k__iterm2_precmd 
	fi
	if (( _POWERLEVEL9K_TERM_SHELL_INTEGRATION  &&
        ! $+_z4h_iterm_cmd                    &&
        ! $+functions[iterm2_decorate_prompt] &&
        ! $+functions[iterm2_precmd] ))
	then
		typeset -gi _p9k__iterm_cmd=0 
	fi
	if _p9k_segment_in_use todo
	then
		if [[ -n ${_p9k__todo_command::=${commands[todo.sh]}} ]]
		then
			local todo_global=/etc/todo/config 
		elif [[ -n ${_p9k__todo_command::=${commands[todo-txt]}} ]]
		then
			local todo_global=/etc/todo-txt/config 
		fi
		if [[ -n $_p9k__todo_command ]]
		then
			_p9k__todo_file="$(exec -a $_p9k__todo_command ${commands[bash]:-:} 3>&1 &>/dev/null -c "
        [ -e \"\$TODOTXT_CFG_FILE\" ] || TODOTXT_CFG_FILE=\$HOME/.todo/config
        [ -e \"\$TODOTXT_CFG_FILE\" ] || TODOTXT_CFG_FILE=\$HOME/todo.cfg
        [ -e \"\$TODOTXT_CFG_FILE\" ] || TODOTXT_CFG_FILE=\$HOME/.todo.cfg
        [ -e \"\$TODOTXT_CFG_FILE\" ] || TODOTXT_CFG_FILE=\${XDG_CONFIG_HOME:-\$HOME/.config}/todo/config
        [ -e \"\$TODOTXT_CFG_FILE\" ] || TODOTXT_CFG_FILE=${(qqq)_p9k__todo_command:h}/todo.cfg
        [ -e \"\$TODOTXT_CFG_FILE\" ] || TODOTXT_CFG_FILE=\${TODOTXT_GLOBAL_CFG_FILE:-${(qqq)todo_global}}
        [ -r \"\$TODOTXT_CFG_FILE\" ] || exit
        source \"\$TODOTXT_CFG_FILE\"
        printf "%s" \"\$TODO_FILE\" >&3")" 
		fi
	fi
	if _p9k_segment_in_use dir && [[ $_POWERLEVEL9K_SHORTEN_STRATEGY == truncate_with_package_name && $+commands[jq] == 0 ]]
	then
		print -rP -- '%F{yellow}WARNING!%f %BPOWERLEVEL9K_SHORTEN_STRATEGY=truncate_with_package_name%b requires %F{green}jq%f.'
		print -rP -- 'Either install %F{green}jq%f or change the value of %BPOWERLEVEL9K_SHORTEN_STRATEGY%b.'
	fi
	_p9k_init_vcs
	if (( _p9k__instant_prompt_disabled ))
	then
		(( _POWERLEVEL9K_DISABLE_INSTANT_PROMPT )) && unset __p9k_instant_prompt_erased
		_p9k_delete_instant_prompt
		_p9k_dumped_instant_prompt_sigs=() 
	fi
	if (( $+__p9k_instant_prompt_sourced && __p9k_instant_prompt_sourced != __p9k_instant_prompt_version ))
	then
		_p9k_delete_instant_prompt
		_p9k_dumped_instant_prompt_sigs=() 
	fi
	if (( $+__p9k_instant_prompt_erased ))
	then
		unset __p9k_instant_prompt_erased
		if [[ -w $TTY ]]
		then
			local tty=$TTY 
		elif [[ -w /dev/tty ]]
		then
			local tty=/dev/tty 
		else
			local tty=/dev/null 
		fi
		{
			echo -E - "" >&2
			echo -E - "${(%):-[%1FERROR%f]: When using instant prompt, Powerlevel10k must be loaded before the first prompt.}" >&2
			echo -E - "" >&2
			echo -E - "${(%):-You can:}" >&2
			echo -E - "" >&2
			echo -E - "${(%):-  - %BRecommended%b: Change the way Powerlevel10k is loaded from %B$__p9k_zshrc_u%b.}" >&2
			if (( _p9k_term_has_href ))
			then
				echo - "${(%):-    See \e]8;;https://github.com/romkatv/powerlevel10k#installation\ahttps://github.com/romkatv/powerlevel10k#installation\e]8;;\a.}" >&2
			else
				echo - "${(%):-    See https://github.com/romkatv/powerlevel10k#installation.}" >&2
			fi
			if (( $+zsh_defer_options ))
			then
				echo -E - "" >&2
				echo -E - "${(%):-    NOTE: Do not use %1Fzsh-defer%f to load %Upowerlevel10k.zsh-theme%u.}" >&2
			elif (( $+functions[zinit] ))
			then
				echo -E - "" >&2
				echo -E - "${(%):-    NOTE: If using %2Fzinit%f to load %3F'romkatv/powerlevel10k'%f, %Bdo not apply%b %1Fice wait%f.}" >&2
			elif (( $+functions[zplugin] ))
			then
				echo -E - "" >&2
				echo -E - "${(%):-    NOTE: If using %2Fzplugin%f to load %3F'romkatv/powerlevel10k'%f, %Bdo not apply%b %1Fice wait%f.}" >&2
			fi
			echo -E - "" >&2
			echo -E - "${(%):-    * You %Bwill not%b see this error message again.}" >&2
			echo -E - "${(%):-    * Zsh will start %Bquickly%b.}" >&2
			echo -E - "" >&2
			echo -E - "${(%):-  - Disable instant prompt either by running %Bp10k configure%b or by manually}" >&2
			echo -E - "${(%):-    defining the following parameter:}" >&2
			echo -E - "" >&2
			echo -E - "${(%):-      %3Ftypeset%f -g POWERLEVEL9K_INSTANT_PROMPT=off}" >&2
			echo -E - "" >&2
			echo -E - "${(%):-    * You %Bwill not%b see this error message again.}" >&2
			echo -E - "${(%):-    * Zsh will start %Bslowly%b.}" >&2
			echo -E - "" >&2
			echo -E - "${(%):-  - Do nothing.}" >&2
			echo -E - "" >&2
			echo -E - "${(%):-    * You %Bwill%b see this error message every time you start zsh.}" >&2
			echo -E - "${(%):-    * Zsh will start %Bslowly%b.}" >&2
			echo -E - "" >&2
		} 2>> $tty
	fi
}
_p9k_init_cacheable () {
	_p9k_init_icons
	_p9k_init_params
	_p9k_init_prompt
	_p9k_init_display
	if [[ $VTE_VERSION != (<1-4602>|4801) ]]
	then
		_p9k_term_has_href=1 
	fi
	local elem func
	local -i i=0 
	for i in {1..$#_p9k_line_segments_left}
	do
		for elem in ${${${(@0)_p9k_line_segments_left[i]}%_joined}//-/_}
		do
			local var=POWERLEVEL9K_${${(U)elem}//İ/I}_SHOW_ON_COMMAND 
			(( $+parameters[$var] )) || continue
			_p9k_show_on_command+=($'(|*[/\0])('${(j.|.)${(P)var}}')' $((1+_p9k_display_k[$i/left/$elem])) _p9k__${i}l$elem) 
		done
		for elem in ${${${(@0)_p9k_line_segments_right[i]}%_joined}//-/_}
		do
			local var=POWERLEVEL9K_${${(U)elem}//İ/I}_SHOW_ON_COMMAND 
			(( $+parameters[$var] )) || continue
			local cmds=(${(P)var}) 
			_p9k_show_on_command+=($'(|*[/\0])('${(j.|.)${(P)var}}')' $((1+$_p9k_display_k[$i/right/$elem])) _p9k__${i}r$elem) 
		done
	done
	if [[ $_POWERLEVEL9K_TRANSIENT_PROMPT != off ]]
	then
		local sep=$'\1' 
		_p9k_transient_prompt='%b%k%s%u%(?'$sep 
		_p9k_color prompt_prompt_char_OK_VIINS FOREGROUND 76
		_p9k_foreground $_p9k__ret
		_p9k_transient_prompt+=$_p9k__ret 
		_p9k_transient_prompt+='${${P9K_CONTENT::="❯"}+}' 
		_p9k_param prompt_prompt_char_OK_VIINS CONTENT_EXPANSION '${P9K_CONTENT}'
		_p9k_transient_prompt+='${:-"'$_p9k__ret'"}' 
		_p9k_transient_prompt+=$sep 
		_p9k_color prompt_prompt_char_ERROR_VIINS FOREGROUND 196
		_p9k_foreground $_p9k__ret
		_p9k_transient_prompt+=$_p9k__ret 
		_p9k_transient_prompt+='${${P9K_CONTENT::="❯"}+}' 
		_p9k_param prompt_prompt_char_ERROR_VIINS CONTENT_EXPANSION '${P9K_CONTENT}'
		_p9k_transient_prompt+='${:-"'$_p9k__ret'"}' 
		_p9k_transient_prompt+=')%b%k%f%s%u' 
		_p9k_get_icon '' LEFT_SEGMENT_END_SEPARATOR
		if [[ $_p9k__ret != (| ) ]]
		then
			_p9k__ret+=%b%k%f 
			_p9k__ret='${:-"'$_p9k__ret'"}' 
		fi
		_p9k_transient_prompt+=$_p9k__ret 
		if (( _POWERLEVEL9K_TERM_SHELL_INTEGRATION ))
		then
			_p9k_transient_prompt=$'%{\e]133;A\a%}'$_p9k_transient_prompt$'%{\e]133;B\a%}' 
			if (( $+_z4h_iterm_cmd && _z4h_can_save_restore_screen == 1 ))
			then
				_p9k_transient_prompt=$'%{\ePtmux;\e\e]133;A\a\e\\%}'$_p9k_transient_prompt$'%{\ePtmux;\e\e]133;B\a\e\\%}' 
			fi
		fi
	fi
	_p9k_uname="$(uname)" 
	[[ $_p9k_uname == Linux ]] && _p9k_uname_o="$(uname -o 2>/dev/null)" 
	_p9k_uname_m="$(uname -m)" 
	if [[ $_p9k_uname == Linux && $_p9k_uname_o == Android ]]
	then
		_p9k_set_os Android ANDROID_ICON
	else
		case $_p9k_uname in
			(SunOS) _p9k_set_os Solaris SUNOS_ICON ;;
			(Darwin) _p9k_set_os OSX APPLE_ICON ;;
			(CYGWIN* | MSYS* | MINGW*) _p9k_set_os Windows WINDOWS_ICON ;;
			(FreeBSD | OpenBSD | DragonFly) _p9k_set_os BSD FREEBSD_ICON ;;
			(Linux) _p9k_os='Linux' 
				local os_release_id
				if [[ -r /etc/os-release ]]
				then
					local lines=(${(f)"$(</etc/os-release)"}) 
					lines=(${(@M)lines:#ID=*}) 
					(( $#lines == 1 )) && os_release_id=${(Q)${lines[1]#ID=}} 
				elif [[ -e /etc/artix-release ]]
				then
					os_release_id=artix 
				fi
				case $os_release_id in
					(*arch*) _p9k_set_os Linux LINUX_ARCH_ICON ;;
					(*raspbian*) _p9k_set_os Linux LINUX_RASPBIAN_ICON ;;
					(*debian*) if [[ -f /etc/apt/sources.list.d/raspi.list ]]
						then
							_p9k_set_os Linux LINUX_RASPBIAN_ICON
						else
							_p9k_set_os Linux LINUX_DEBIAN_ICON
						fi ;;
					(*ubuntu*) _p9k_set_os Linux LINUX_UBUNTU_ICON ;;
					(*elementary*) _p9k_set_os Linux LINUX_ELEMENTARY_ICON ;;
					(*fedora*) _p9k_set_os Linux LINUX_FEDORA_ICON ;;
					(*coreos*) _p9k_set_os Linux LINUX_COREOS_ICON ;;
					(*kali*) _p9k_set_os Linux LINUX_KALI_ICON ;;
					(*gentoo*) _p9k_set_os Linux LINUX_GENTOO_ICON ;;
					(*mageia*) _p9k_set_os Linux LINUX_MAGEIA_ICON ;;
					(*centos*) _p9k_set_os Linux LINUX_CENTOS_ICON ;;
					(*opensuse* | *tumbleweed*) _p9k_set_os Linux LINUX_OPENSUSE_ICON ;;
					(*sabayon*) _p9k_set_os Linux LINUX_SABAYON_ICON ;;
					(*slackware*) _p9k_set_os Linux LINUX_SLACKWARE_ICON ;;
					(*linuxmint*) _p9k_set_os Linux LINUX_MINT_ICON ;;
					(*alpine*) _p9k_set_os Linux LINUX_ALPINE_ICON ;;
					(*aosc*) _p9k_set_os Linux LINUX_AOSC_ICON ;;
					(*nixos*) _p9k_set_os Linux LINUX_NIXOS_ICON ;;
					(*devuan*) _p9k_set_os Linux LINUX_DEVUAN_ICON ;;
					(*manjaro*) _p9k_set_os Linux LINUX_MANJARO_ICON ;;
					(*void*) _p9k_set_os Linux LINUX_VOID_ICON ;;
					(*artix*) _p9k_set_os Linux LINUX_ARTIX_ICON ;;
					(*rhel*) _p9k_set_os Linux LINUX_RHEL_ICON ;;
					(amzn) _p9k_set_os Linux LINUX_AMZN_ICON ;;
					(endeavouros) _p9k_set_os Linux LINUX_ENDEAVOUROS_ICON ;;
					(rocky) _p9k_set_os Linux LINUX_ROCKY_ICON ;;
					(almalinux) _p9k_set_os Linux LINUX_ALMALINUX_ICON ;;
					(guix) _p9k_set_os Linux LINUX_GUIX_ICON ;;
					(neon) _p9k_set_os Linux LINUX_NEON_ICON ;;
					(*) _p9k_set_os Linux LINUX_ICON ;;
				esac ;;
		esac
	fi
	if [[ $_POWERLEVEL9K_COLOR_SCHEME == light ]]
	then
		_p9k_color1=7 
		_p9k_color2=0 
	else
		_p9k_color1=0 
		_p9k_color2=7 
	fi
	_p9k_battery_states=('LOW' 'red' 'CHARGING' 'yellow' 'CHARGED' 'green' 'DISCONNECTED' "$_p9k_color2") 
	local -a left_segments=(${(@0)${(pj:\0:)_p9k_line_segments_left}}) 
	_p9k_left_join=(1) 
	for ((i = 2; i <= $#left_segments; ++i)) do
		elem=$left_segments[i] 
		if [[ $elem == *_joined ]]
		then
			_p9k_left_join+=$_p9k_left_join[((i-1))] 
		else
			_p9k_left_join+=$i 
		fi
	done
	local -a right_segments=(${(@0)${(pj:\0:)_p9k_line_segments_right}}) 
	_p9k_right_join=(1) 
	for ((i = 2; i <= $#right_segments; ++i)) do
		elem=$right_segments[i] 
		if [[ $elem == *_joined ]]
		then
			_p9k_right_join+=$_p9k_right_join[((i-1))] 
		else
			_p9k_right_join+=$i 
		fi
	done
	case $_p9k_os in
		(OSX) (( $+commands[sysctl] )) && _p9k_num_cpus="$(sysctl -n hw.logicalcpu 2>/dev/null)"  ;;
		(BSD) (( $+commands[sysctl] )) && _p9k_num_cpus="$(sysctl -n hw.ncpu 2>/dev/null)"  ;;
		(*) (( $+commands[nproc]  )) && _p9k_num_cpus="$(nproc 2>/dev/null)"  ;;
	esac
	(( _p9k_num_cpus )) || _p9k_num_cpus=1 
	if _p9k_segment_in_use dir
	then
		if (( $+_POWERLEVEL9K_DIR_CLASSES ))
		then
			local -i i=3 
			for ((; i <= $#_POWERLEVEL9K_DIR_CLASSES; i+=3)) do
				_POWERLEVEL9K_DIR_CLASSES[i]=${(g::)_POWERLEVEL9K_DIR_CLASSES[i]} 
			done
		else
			typeset -ga _POWERLEVEL9K_DIR_CLASSES=() 
			_p9k_get_icon prompt_dir_ETC ETC_ICON
			_POWERLEVEL9K_DIR_CLASSES+=('/etc|/etc/*' ETC "$_p9k__ret") 
			_p9k_get_icon prompt_dir_HOME HOME_ICON
			_POWERLEVEL9K_DIR_CLASSES+=('~' HOME "$_p9k__ret") 
			_p9k_get_icon prompt_dir_HOME_SUBFOLDER HOME_SUB_ICON
			_POWERLEVEL9K_DIR_CLASSES+=('~/*' HOME_SUBFOLDER "$_p9k__ret") 
			_p9k_get_icon prompt_dir_DEFAULT FOLDER_ICON
			_POWERLEVEL9K_DIR_CLASSES+=('*' DEFAULT "$_p9k__ret") 
		fi
	fi
	if _p9k_segment_in_use status
	then
		typeset -g _p9k_exitcode2str=({0..255}) 
		local -i i=2 
		if (( !_POWERLEVEL9K_STATUS_HIDE_SIGNAME ))
		then
			for ((; i <= $#signals; ++i)) do
				local sig=$signals[i] 
				(( _POWERLEVEL9K_STATUS_VERBOSE_SIGNAME )) && sig="SIG${sig}($((i-1)))" 
				_p9k_exitcode2str[$((128+i))]=$sig 
			done
		fi
	fi
	if [[ $#_POWERLEVEL9K_VCS_BACKENDS == 1 && $_POWERLEVEL9K_VCS_BACKENDS[1] == git ]]
	then
		local elem line
		local -i i=0 line_idx=0 
		for line in $_p9k_line_segments_left
		do
			(( ++line_idx ))
			for elem in ${${(0)line}%_joined}
			do
				(( ++i ))
				if [[ $elem == vcs ]]
				then
					if (( _p9k_vcs_index ))
					then
						_p9k_vcs_index=-1 
					else
						_p9k_vcs_index=i 
						_p9k_vcs_line_index=line_idx 
						_p9k_vcs_side=left 
					fi
				fi
			done
		done
		i=0 
		line_idx=0 
		for line in $_p9k_line_segments_right
		do
			(( ++line_idx ))
			for elem in ${${(0)line}%_joined}
			do
				(( ++i ))
				if [[ $elem == vcs ]]
				then
					if (( _p9k_vcs_index ))
					then
						_p9k_vcs_index=-1 
					else
						_p9k_vcs_index=i 
						_p9k_vcs_line_index=line_idx 
						_p9k_vcs_side=right 
					fi
				fi
			done
		done
		if (( _p9k_vcs_index > 0 ))
		then
			local state
			for state in ${(k)__p9k_vcs_states}
			do
				_p9k_param prompt_vcs_$state CONTENT_EXPANSION x
				if [[ -z $_p9k__ret ]]
				then
					_p9k_vcs_index=-1 
					break
				fi
			done
		fi
		if (( _p9k_vcs_index == -1 ))
		then
			_p9k_vcs_index=0 
			_p9k_vcs_line_index=0 
			_p9k_vcs_side= 
		fi
	fi
}
_p9k_init_display () {
	_p9k_display_k=(empty_line 1 ruler 3) 
	local -i n=3 i 
	local name
	for i in {1..$#_p9k_line_segments_left}
	do
		local -i j=$((-$#_p9k_line_segments_left+i-1)) 
		_p9k_display_k+=($i $((n+=2)) $j $n $i/left_frame $((n+=2)) $j/left_frame $n $i/right_frame $((n+=2)) $j/right_frame $n $i/left $((n+=2)) $j/left $n $i/right $((n+=2)) $j/right $n $i/gap $((n+=2)) $j/gap $n) 
		for name in ${${(@0)_p9k_line_segments_left[i]}%_joined}
		do
			_p9k_display_k+=($i/left/$name $((n+=2)) $j/left/$name $n) 
		done
		for name in ${${(@0)_p9k_line_segments_right[i]}%_joined}
		do
			_p9k_display_k+=($i/right/$name $((n+=2)) $j/right/$name $n) 
		done
	done
}
_p9k_init_icons () {
	[[ -n ${POWERLEVEL9K_MODE-} || ${langinfo[CODESET]} == (utf|UTF)(-|)8 ]] || local POWERLEVEL9K_MODE=ascii 
	[[ $_p9k__icon_mode == $POWERLEVEL9K_MODE/$POWERLEVEL9K_LEGACY_ICON_SPACING/$POWERLEVEL9K_ICON_PADDING ]] && return
	typeset -g _p9k__icon_mode=$POWERLEVEL9K_MODE/$POWERLEVEL9K_LEGACY_ICON_SPACING/$POWERLEVEL9K_ICON_PADDING 
	if [[ $POWERLEVEL9K_LEGACY_ICON_SPACING == true ]]
	then
		local s= 
		local q=' ' 
	else
		local s=' ' 
		local q= 
	fi
	case $POWERLEVEL9K_MODE in
		('flat' | 'awesome-patched') icons=(RULER_CHAR '\u2500' LEFT_SEGMENT_SEPARATOR '\uE0B0' RIGHT_SEGMENT_SEPARATOR '\uE0B2' LEFT_SEGMENT_END_SEPARATOR ' ' LEFT_SUBSEGMENT_SEPARATOR '\uE0B1' RIGHT_SUBSEGMENT_SEPARATOR '\uE0B3' CARRIAGE_RETURN_ICON '\u21B5'$s ROOT_ICON '\uE801' SUDO_ICON '\uE0A2' RUBY_ICON '\uE847 ' AWS_ICON '\uE895'$s AWS_EB_ICON '\U1F331'$q BACKGROUND_JOBS_ICON '\uE82F ' TEST_ICON '\uE891'$s TODO_ICON '\u2611' BATTERY_ICON '\uE894'$s DISK_ICON '\uE1AE ' OK_ICON '\u2714' FAIL_ICON '\u2718' SYMFONY_ICON 'SF' NODE_ICON '\u2B22'$s NODEJS_ICON '\u2B22'$s MULTILINE_FIRST_PROMPT_PREFIX '\u256D\U2500' MULTILINE_NEWLINE_PROMPT_PREFIX '\u251C\U2500' MULTILINE_LAST_PROMPT_PREFIX '\u2570\U2500 ' APPLE_ICON '\uE26E'$s WINDOWS_ICON '\uE26F'$s FREEBSD_ICON '\U1F608'$q ANDROID_ICON '\uE270'$s LINUX_ICON '\uE271'$s LINUX_ARCH_ICON '\uE271'$s LINUX_DEBIAN_ICON '\uE271'$s LINUX_RASPBIAN_ICON '\uE271'$s LINUX_UBUNTU_ICON '\uE271'$s LINUX_KALI_ICON '\uE271'$s LINUX_CENTOS_ICON '\uE271'$s LINUX_COREOS_ICON '\uE271'$s LINUX_ELEMENTARY_ICON '\uE271'$s LINUX_MINT_ICON '\uE271'$s LINUX_FEDORA_ICON '\uE271'$s LINUX_GENTOO_ICON '\uE271'$s LINUX_MAGEIA_ICON '\uE271'$s LINUX_NIXOS_ICON '\uE271'$s LINUX_MANJARO_ICON '\uE271'$s LINUX_DEVUAN_ICON '\uE271'$s LINUX_ALPINE_ICON '\uE271'$s LINUX_AOSC_ICON '\uE271'$s LINUX_OPENSUSE_ICON '\uE271'$s LINUX_SABAYON_ICON '\uE271'$s LINUX_SLACKWARE_ICON '\uE271'$s LINUX_VOID_ICON '\uE271'$s LINUX_ARTIX_ICON '\uE271'$s LINUX_RHEL_ICON '\uE271'$s LINUX_AMZN_ICON '\uE271'$s LINUX_ENDEAVOUROS_ICON '\uE271'$s LINUX_ROCKY_ICON '\uE271'$s LINUX_ALMALINUX_ICON '\uE271'$s LINUX_GUIX_ICON '\uE271'$s LINUX_NEON_ICON '\uE271'$s SUNOS_ICON '\U1F31E'$q HOME_ICON '\uE12C'$s HOME_SUB_ICON '\uE18D'$s FOLDER_ICON '\uE818'$s NETWORK_ICON '\uE1AD'$s ETC_ICON '\uE82F'$s LOAD_ICON '\uE190 ' SWAP_ICON '\uE87D'$s RAM_ICON '\uE1E2 ' SERVER_ICON '\uE895'$s VCS_UNTRACKED_ICON '\uE16C'$s VCS_UNSTAGED_ICON '\uE17C'$s VCS_STAGED_ICON '\uE168'$s VCS_STASH_ICON '\uE133 ' VCS_INCOMING_CHANGES_ICON '\uE131 ' VCS_OUTGOING_CHANGES_ICON '\uE132 ' VCS_TAG_ICON '\uE817 ' VCS_BOOKMARK_ICON '\uE87B' VCS_COMMIT_ICON '\uE821 ' VCS_BRANCH_ICON '\uE220 ' VCS_REMOTE_BRANCH_ICON '\u2192' VCS_LOADING_ICON '' VCS_GIT_ICON '\uE20E ' VCS_GIT_GITHUB_ICON '\uE20E ' VCS_GIT_BITBUCKET_ICON '\uE20E ' VCS_GIT_GITLAB_ICON '\uE20E ' VCS_GIT_AZURE_ICON '\uE20E ' VCS_GIT_ARCHLINUX_ICON '\uE20E ' VCS_GIT_CODEBERG_ICON '\uE20E ' VCS_GIT_DEBIAN_ICON '\uE20E ' VCS_GIT_FREEBSD_ICON '\uE20E ' VCS_GIT_FREEDESKTOP_ICON '\uE20E ' VCS_GIT_GNOME_ICON '\uE20E ' VCS_GIT_GNU_ICON '\uE20E ' VCS_GIT_KDE_ICON '\uE20E ' VCS_GIT_LINUX_ICON '\uE20E ' VCS_GIT_GITEA_ICON '\uE20E ' VCS_GIT_SOURCEHUT_ICON '\uE20E ' VCS_HG_ICON '\uE1C3 ' VCS_SVN_ICON 'svn'$q RUST_ICON 'R' PYTHON_ICON '\uE63C'$s CHEZMOI_ICON '\uE12C'$s SWIFT_ICON 'Swift' GO_ICON 'Go' GOLANG_ICON 'Go' PUBLIC_IP_ICON 'IP' LOCK_ICON '\UE138' NORDVPN_ICON '\UE138' EXECUTION_TIME_ICON '\UE89C'$s SSH_ICON 'ssh' VPN_ICON '\UE138' KUBERNETES_ICON '\U2388'$s DROPBOX_ICON '\UF16B'$s DATE_ICON '\uE184'$s TIME_ICON '\uE12E'$s JAVA_ICON '\U2615' LARAVEL_ICON '' RANGER_ICON '\u2B50' YAZI_ICON '\u2B50' MIDNIGHT_COMMANDER_ICON 'mc' VIM_ICON 'vim' TERRAFORM_ICON 'tf' PROXY_ICON '\u2194' DOTNET_ICON '.NET' DOTNET_CORE_ICON '.NET' AZURE_ICON '\u2601' DIRENV_ICON '\u25BC' FLUTTER_ICON 'F' GCLOUD_ICON 'G' LUA_ICON 'lua' PERL_ICON 'perl' NNN_ICON 'nnn' LF_ICON 'lf' XPLR_ICON 'xplr' TIMEWARRIOR_ICON 'tw' TASKWARRIOR_ICON 'task' NIX_SHELL_ICON 'nix' WIFI_ICON 'WiFi' ERLANG_ICON 'erl' ELIXIR_ICON 'elixir' POSTGRES_ICON 'postgres' PHP_ICON 'php' HASKELL_ICON 'hs' PACKAGE_ICON 'pkg' JULIA_ICON 'jl' SCALA_ICON 'scala' TOOLBOX_ICON '\u2B22' ARCH_ICON 'arch' HISTORY_ICON 'hist')  ;;
		('awesome-fontconfig') icons=(RULER_CHAR '\u2500' LEFT_SEGMENT_SEPARATOR '\uE0B0' RIGHT_SEGMENT_SEPARATOR '\uE0B2' LEFT_SEGMENT_END_SEPARATOR ' ' LEFT_SUBSEGMENT_SEPARATOR '\uE0B1' RIGHT_SUBSEGMENT_SEPARATOR '\uE0B3' CARRIAGE_RETURN_ICON '\u21B5' ROOT_ICON '\uF201'$s SUDO_ICON '\uF09C'$s RUBY_ICON '\uF219 ' AWS_ICON '\uF270'$s AWS_EB_ICON '\U1F331'$q BACKGROUND_JOBS_ICON '\uF013 ' TEST_ICON '\uF291'$s TODO_ICON '\u2611' BATTERY_ICON '\U1F50B' DISK_ICON '\uF0A0 ' OK_ICON '\u2714' FAIL_ICON '\u2718' SYMFONY_ICON 'SF' NODE_ICON '\u2B22' NODEJS_ICON '\u2B22' MULTILINE_FIRST_PROMPT_PREFIX '\u256D\U2500' MULTILINE_NEWLINE_PROMPT_PREFIX '\u251C\U2500' MULTILINE_LAST_PROMPT_PREFIX '\u2570\U2500 ' APPLE_ICON '\uF179'$s WINDOWS_ICON '\uF17A'$s FREEBSD_ICON '\U1F608'$q ANDROID_ICON '\uE17B'$s LINUX_ICON '\uF17C'$s LINUX_ARCH_ICON '\uF17C'$s LINUX_DEBIAN_ICON '\uF17C'$s LINUX_RASPBIAN_ICON '\uF17C'$s LINUX_UBUNTU_ICON '\uF17C'$s LINUX_KALI_ICON '\uF17C'$s LINUX_CENTOS_ICON '\uF17C'$s LINUX_COREOS_ICON '\uF17C'$s LINUX_ELEMENTARY_ICON '\uF17C'$s LINUX_MINT_ICON '\uF17C'$s LINUX_FEDORA_ICON '\uF17C'$s LINUX_GENTOO_ICON '\uF17C'$s LINUX_MAGEIA_ICON '\uF17C'$s LINUX_NIXOS_ICON '\uF17C'$s LINUX_MANJARO_ICON '\uF17C'$s LINUX_DEVUAN_ICON '\uF17C'$s LINUX_ALPINE_ICON '\uF17C'$s LINUX_AOSC_ICON '\uF17C'$s LINUX_OPENSUSE_ICON '\uF17C'$s LINUX_SABAYON_ICON '\uF17C'$s LINUX_SLACKWARE_ICON '\uF17C'$s LINUX_VOID_ICON '\uF17C'$s LINUX_ARTIX_ICON '\uF17C'$s LINUX_RHEL_ICON '\uF17C'$s LINUX_AMZN_ICON '\uF17C'$s LINUX_ENDEAVOUROS_ICON '\uF17C'$s LINUX_ROCKY_ICON '\uF17C'$s LINUX_ALMALINUX_ICON '\uF17C'$s LINUX_GUIX_ICON '\uF17C'$s LINUX_NEON_ICON '\uF17C'$s SUNOS_ICON '\uF185 ' HOME_ICON '\uF015'$s HOME_SUB_ICON '\uF07C'$s FOLDER_ICON '\uF115'$s ETC_ICON '\uF013 ' NETWORK_ICON '\uF09E'$s LOAD_ICON '\uF080 ' SWAP_ICON '\uF0E4'$s RAM_ICON '\uF0E4'$s SERVER_ICON '\uF233'$s VCS_UNTRACKED_ICON '\uF059'$s VCS_UNSTAGED_ICON '\uF06A'$s VCS_STAGED_ICON '\uF055'$s VCS_STASH_ICON '\uF01C ' VCS_INCOMING_CHANGES_ICON '\uF01A ' VCS_OUTGOING_CHANGES_ICON '\uF01B ' VCS_TAG_ICON '\uF217 ' VCS_BOOKMARK_ICON '\uF27B ' VCS_COMMIT_ICON '\uF221 ' VCS_BRANCH_ICON '\uF126 ' VCS_REMOTE_BRANCH_ICON '\u2192' VCS_LOADING_ICON '' VCS_GIT_ICON '\uF1D3 ' VCS_GIT_GITHUB_ICON '\uF113 ' VCS_GIT_BITBUCKET_ICON '\uF171 ' VCS_GIT_GITLAB_ICON '\uF296 ' VCS_GIT_AZURE_ICON '\u2601 ' VCS_GIT_ARCHLINUX_ICON '\uF1D3 ' VCS_GIT_CODEBERG_ICON '\uF1D3 ' VCS_GIT_DEBIAN_ICON '\uF1D3 ' VCS_GIT_FREEBSD_ICON '\uF1D3 ' VCS_GIT_FREEDESKTOP_ICON '\uF1D3 ' VCS_GIT_GNOME_ICON '\uF1D3 ' VCS_GIT_GNU_ICON '\uF1D3 ' VCS_GIT_KDE_ICON '\uF1D3 ' VCS_GIT_LINUX_ICON '\uF1D3 ' VCS_GIT_GITEA_ICON '\uF1D3 ' VCS_GIT_SOURCEHUT_ICON '\uF1D3 ' VCS_HG_ICON '\uF0C3 ' VCS_SVN_ICON 'svn'$q RUST_ICON '\uE6A8' PYTHON_ICON '\uE63C'$s CHEZMOI_ICON '\uF015'$s SWIFT_ICON 'Swift' GO_ICON 'Go' GOLANG_ICON 'Go' PUBLIC_IP_ICON 'IP' LOCK_ICON '\UF023' NORDVPN_ICON '\UF023' EXECUTION_TIME_ICON '\uF253'$s SSH_ICON 'ssh' VPN_ICON '\uF023' KUBERNETES_ICON '\U2388' DROPBOX_ICON '\UF16B'$s DATE_ICON '\uF073 ' TIME_ICON '\uF017 ' JAVA_ICON '\U2615' LARAVEL_ICON '' RANGER_ICON '\u2B50' YAZI_ICON '\u2B50' MIDNIGHT_COMMANDER_ICON 'mc' VIM_ICON 'vim' TERRAFORM_ICON 'tf' PROXY_ICON '\u2194' DOTNET_ICON '.NET' DOTNET_CORE_ICON '.NET' AZURE_ICON '\u2601' DIRENV_ICON '\u25BC' FLUTTER_ICON 'F' GCLOUD_ICON 'G' LUA_ICON 'lua' PERL_ICON 'perl' NNN_ICON 'nnn' LF_ICON 'lf' XPLR_ICON 'xplr' TIMEWARRIOR_ICON 'tw' TASKWARRIOR_ICON 'task' NIX_SHELL_ICON 'nix' WIFI_ICON 'WiFi' ERLANG_ICON 'erl' ELIXIR_ICON 'elixir' POSTGRES_ICON 'postgres' PHP_ICON 'php' HASKELL_ICON 'hs' PACKAGE_ICON 'pkg' JULIA_ICON 'jl' SCALA_ICON 'scala' TOOLBOX_ICON '\u2B22' ARCH_ICON 'arch' HISTORY_ICON 'hist')  ;;
		('awesome-mapped-fontconfig') if [ -z "$AWESOME_GLYPHS_LOADED" ]
			then
				echo "Powerlevel9k warning: Awesome-Font mappings have not been loaded.
          Source a font mapping in your shell config, per the Awesome-Font docs
          (https://github.com/gabrielelana/awesome-terminal-fonts),
          Or use a different Powerlevel9k font configuration."
			fi
			icons=(RULER_CHAR '\u2500' LEFT_SEGMENT_SEPARATOR '\uE0B0' RIGHT_SEGMENT_SEPARATOR '\uE0B2' LEFT_SEGMENT_END_SEPARATOR ' ' LEFT_SUBSEGMENT_SEPARATOR '\uE0B1' RIGHT_SUBSEGMENT_SEPARATOR '\uE0B3' CARRIAGE_RETURN_ICON '\u21B5' ROOT_ICON "${CODEPOINT_OF_OCTICONS_ZAP:+\\u$CODEPOINT_OF_OCTICONS_ZAP}" SUDO_ICON "${CODEPOINT_OF_AWESOME_UNLOCK:+\\u$CODEPOINT_OF_AWESOME_UNLOCK$s}" RUBY_ICON "${CODEPOINT_OF_OCTICONS_RUBY:+\\u$CODEPOINT_OF_OCTICONS_RUBY }" AWS_ICON "${CODEPOINT_OF_AWESOME_SERVER:+\\u$CODEPOINT_OF_AWESOME_SERVER$s}" AWS_EB_ICON '\U1F331'$q BACKGROUND_JOBS_ICON "${CODEPOINT_OF_AWESOME_COG:+\\u$CODEPOINT_OF_AWESOME_COG }" TEST_ICON "${CODEPOINT_OF_AWESOME_BUG:+\\u$CODEPOINT_OF_AWESOME_BUG$s}" TODO_ICON "${CODEPOINT_OF_AWESOME_CHECK_SQUARE_O:+\\u$CODEPOINT_OF_AWESOME_CHECK_SQUARE_O$s}" BATTERY_ICON "${CODEPOINT_OF_AWESOME_BATTERY_FULL:+\\U$CODEPOINT_OF_AWESOME_BATTERY_FULL$s}" DISK_ICON "${CODEPOINT_OF_AWESOME_HDD_O:+\\u$CODEPOINT_OF_AWESOME_HDD_O }" OK_ICON "${CODEPOINT_OF_AWESOME_CHECK:+\\u$CODEPOINT_OF_AWESOME_CHECK$s}" FAIL_ICON "${CODEPOINT_OF_AWESOME_TIMES:+\\u$CODEPOINT_OF_AWESOME_TIMES}" SYMFONY_ICON 'SF' NODE_ICON '\u2B22' NODEJS_ICON '\u2B22' MULTILINE_FIRST_PROMPT_PREFIX '\u256D\U2500' MULTILINE_NEWLINE_PROMPT_PREFIX '\u251C\U2500' MULTILINE_LAST_PROMPT_PREFIX '\u2570\U2500 ' APPLE_ICON "${CODEPOINT_OF_AWESOME_APPLE:+\\u$CODEPOINT_OF_AWESOME_APPLE$s}" FREEBSD_ICON '\U1F608'$q LINUX_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_ARCH_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_DEBIAN_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_RASPBIAN_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_UBUNTU_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_KALI_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_CENTOS_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_COREOS_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_ELEMENTARY_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_MINT_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_FEDORA_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_GENTOO_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_MAGEIA_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_NIXOS_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_MANJARO_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_DEVUAN_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_ALPINE_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_AOSC_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_OPENSUSE_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_SABAYON_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_SLACKWARE_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_VOID_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_ARTIX_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_RHEL_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_AMZN_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_ENDEAVOUROS_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_ROCKY_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_ALMALINUX_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_GUIX_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" LINUX_NEON_ICON "${CODEPOINT_OF_AWESOME_LINUX:+\\u$CODEPOINT_OF_AWESOME_LINUX$s}" SUNOS_ICON "${CODEPOINT_OF_AWESOME_SUN_O:+\\u$CODEPOINT_OF_AWESOME_SUN_O }" HOME_ICON "${CODEPOINT_OF_AWESOME_HOME:+\\u$CODEPOINT_OF_AWESOME_HOME$s}" HOME_SUB_ICON "${CODEPOINT_OF_AWESOME_FOLDER_OPEN:+\\u$CODEPOINT_OF_AWESOME_FOLDER_OPEN$s}" FOLDER_ICON "${CODEPOINT_OF_AWESOME_FOLDER_O:+\\u$CODEPOINT_OF_AWESOME_FOLDER_O$s}" ETC_ICON "${CODEPOINT_OF_AWESOME_COG:+\\u$CODEPOINT_OF_AWESOME_COG }" NETWORK_ICON "${CODEPOINT_OF_AWESOME_RSS:+\\u$CODEPOINT_OF_AWESOME_RSS$s}" LOAD_ICON "${CODEPOINT_OF_AWESOME_BAR_CHART:+\\u$CODEPOINT_OF_AWESOME_BAR_CHART }" SWAP_ICON "${CODEPOINT_OF_AWESOME_DASHBOARD:+\\u$CODEPOINT_OF_AWESOME_DASHBOARD$s}" RAM_ICON "${CODEPOINT_OF_AWESOME_DASHBOARD:+\\u$CODEPOINT_OF_AWESOME_DASHBOARD$s}" SERVER_ICON "${CODEPOINT_OF_AWESOME_SERVER:+\\u$CODEPOINT_OF_AWESOME_SERVER$s}" VCS_UNTRACKED_ICON "${CODEPOINT_OF_AWESOME_QUESTION_CIRCLE:+\\u$CODEPOINT_OF_AWESOME_QUESTION_CIRCLE$s}" VCS_UNSTAGED_ICON "${CODEPOINT_OF_AWESOME_EXCLAMATION_CIRCLE:+\\u$CODEPOINT_OF_AWESOME_EXCLAMATION_CIRCLE$s}" VCS_STAGED_ICON "${CODEPOINT_OF_AWESOME_PLUS_CIRCLE:+\\u$CODEPOINT_OF_AWESOME_PLUS_CIRCLE$s}" VCS_STASH_ICON "${CODEPOINT_OF_AWESOME_INBOX:+\\u$CODEPOINT_OF_AWESOME_INBOX }" VCS_INCOMING_CHANGES_ICON "${CODEPOINT_OF_AWESOME_ARROW_CIRCLE_DOWN:+\\u$CODEPOINT_OF_AWESOME_ARROW_CIRCLE_DOWN }" VCS_OUTGOING_CHANGES_ICON "${CODEPOINT_OF_AWESOME_ARROW_CIRCLE_UP:+\\u$CODEPOINT_OF_AWESOME_ARROW_CIRCLE_UP }" VCS_TAG_ICON "${CODEPOINT_OF_AWESOME_TAG:+\\u$CODEPOINT_OF_AWESOME_TAG }" VCS_BOOKMARK_ICON "${CODEPOINT_OF_OCTICONS_BOOKMARK:+\\u$CODEPOINT_OF_OCTICONS_BOOKMARK}" VCS_COMMIT_ICON "${CODEPOINT_OF_OCTICONS_GIT_COMMIT:+\\u$CODEPOINT_OF_OCTICONS_GIT_COMMIT }" VCS_BRANCH_ICON "${CODEPOINT_OF_OCTICONS_GIT_BRANCH:+\\u$CODEPOINT_OF_OCTICONS_GIT_BRANCH }" VCS_REMOTE_BRANCH_ICON "${CODEPOINT_OF_OCTICONS_REPO_PUSH:+\\u$CODEPOINT_OF_OCTICONS_REPO_PUSH$s}" VCS_LOADING_ICON '' VCS_GIT_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_GITHUB_ICON "${CODEPOINT_OF_AWESOME_GITHUB_ALT:+\\u$CODEPOINT_OF_AWESOME_GITHUB_ALT }" VCS_GIT_BITBUCKET_ICON "${CODEPOINT_OF_AWESOME_BITBUCKET:+\\u$CODEPOINT_OF_AWESOME_BITBUCKET }" VCS_GIT_GITLAB_ICON "${CODEPOINT_OF_AWESOME_GITLAB:+\\u$CODEPOINT_OF_AWESOME_GITLAB }" VCS_GIT_AZURE_ICON '\u2601 ' VCS_GIT_ARCHLINUX_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_CODEBERG_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_DEBIAN_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_FREEBSD_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_FREEDESKTOP_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_GNOME_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_GNU_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_KDE_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_LINUX_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_GITEA_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_GIT_SOURCEHUT_ICON "${CODEPOINT_OF_AWESOME_GIT:+\\u$CODEPOINT_OF_AWESOME_GIT }" VCS_HG_ICON "${CODEPOINT_OF_AWESOME_FLASK:+\\u$CODEPOINT_OF_AWESOME_FLASK }" VCS_SVN_ICON 'svn'$q RUST_ICON '\uE6A8' PYTHON_ICON '\U1F40D' CHEZMOI_ICON "${CODEPOINT_OF_AWESOME_HOME:+\\u$CODEPOINT_OF_AWESOME_HOME$s}" SWIFT_ICON '\uE655'$s PUBLIC_IP_ICON "${CODEPOINT_OF_AWESOME_GLOBE:+\\u$CODEPOINT_OF_AWESOME_GLOBE$s}" LOCK_ICON "${CODEPOINT_OF_AWESOME_LOCK:+\\u$CODEPOINT_OF_AWESOME_LOCK}" NORDVPN_ICON "${CODEPOINT_OF_AWESOME_LOCK:+\\u$CODEPOINT_OF_AWESOME_LOCK}" EXECUTION_TIME_ICON "${CODEPOINT_OF_AWESOME_HOURGLASS_END:+\\u$CODEPOINT_OF_AWESOME_HOURGLASS_END$s}" SSH_ICON 'ssh' VPN_ICON "${CODEPOINT_OF_AWESOME_LOCK:+\\u$CODEPOINT_OF_AWESOME_LOCK}" KUBERNETES_ICON '\U2388' DROPBOX_ICON "${CODEPOINT_OF_AWESOME_DROPBOX:+\\u$CODEPOINT_OF_AWESOME_DROPBOX$s}" DATE_ICON '\uF073 ' TIME_ICON '\uF017 ' JAVA_ICON '\U2615' LARAVEL_ICON '' RANGER_ICON '\u2B50' YAZI_ICON '\u2B50' MIDNIGHT_COMMANDER_ICON 'mc' VIM_ICON 'vim' TERRAFORM_ICON 'tf' PROXY_ICON '\u2194' DOTNET_ICON '.NET' DOTNET_CORE_ICON '.NET' AZURE_ICON '\u2601' DIRENV_ICON '\u25BC' FLUTTER_ICON 'F' GCLOUD_ICON 'G' LUA_ICON 'lua' PERL_ICON 'perl' NNN_ICON 'nnn' LF_ICON 'lf' XPLR_ICON 'xplr' TIMEWARRIOR_ICON 'tw' TASKWARRIOR_ICON 'task' NIX_SHELL_ICON 'nix' WIFI_ICON 'WiFi' ERLANG_ICON 'erl' ELIXIR_ICON 'elixir' POSTGRES_ICON 'postgres' PHP_ICON 'php' HASKELL_ICON 'hs' PACKAGE_ICON 'pkg' JULIA_ICON 'jl' SCALA_ICON 'scala' TOOLBOX_ICON '\u2B22' ARCH_ICON 'arch' HISTORY_ICON 'hist')  ;;
		('nerdfont-v3') icons=(RULER_CHAR '\u2500' LEFT_SEGMENT_SEPARATOR '\uE0B0' RIGHT_SEGMENT_SEPARATOR '\uE0B2' LEFT_SEGMENT_END_SEPARATOR ' ' LEFT_SUBSEGMENT_SEPARATOR '\uE0B1' RIGHT_SUBSEGMENT_SEPARATOR '\uE0B3' CARRIAGE_RETURN_ICON '\u21B5' ROOT_ICON '\uE614'$q SUDO_ICON '\uF09C'$s RUBY_ICON '\uF219 ' AWS_ICON '\uF270'$s AWS_EB_ICON '\UF1BD'$q$q BACKGROUND_JOBS_ICON '\uF013 ' TEST_ICON '\uF188'$s TODO_ICON '\u2611' BATTERY_ICON '\UF240 ' DISK_ICON '\uF0A0'$s OK_ICON '\uF00C'$s FAIL_ICON '\uF00D' SYMFONY_ICON '\uE757' NODE_ICON '\uE617 ' NODEJS_ICON '\uE617 ' MULTILINE_FIRST_PROMPT_PREFIX '\u256D\U2500' MULTILINE_NEWLINE_PROMPT_PREFIX '\u251C\U2500' MULTILINE_LAST_PROMPT_PREFIX '\u2570\U2500 ' APPLE_ICON '\uF179' WINDOWS_ICON '\uF17A'$s FREEBSD_ICON '\UF30C ' ANDROID_ICON '\uF17B' LINUX_ARCH_ICON '\uF303' LINUX_CENTOS_ICON '\uF304'$s LINUX_COREOS_ICON '\uF305'$s LINUX_DEBIAN_ICON '\uF306' LINUX_RASPBIAN_ICON '\uF315' LINUX_ELEMENTARY_ICON '\uF309'$s LINUX_FEDORA_ICON '\uF30a'$s LINUX_GENTOO_ICON '\uF30d'$s LINUX_MAGEIA_ICON '\uF310' LINUX_MINT_ICON '\uF30e'$s LINUX_NIXOS_ICON '\uF313'$s LINUX_MANJARO_ICON '\uF312'$s LINUX_DEVUAN_ICON '\uF307'$s LINUX_ALPINE_ICON '\uF300'$s LINUX_AOSC_ICON '\uF301'$s LINUX_OPENSUSE_ICON '\uF314'$s LINUX_SABAYON_ICON '\uF317'$s LINUX_SLACKWARE_ICON '\uF319'$s LINUX_VOID_ICON '\UF32E'$s LINUX_ARTIX_ICON '\UF31F'$s LINUX_UBUNTU_ICON '\uF31b'$s LINUX_KALI_ICON '\uF327'$s LINUX_RHEL_ICON '\UF111B'$s LINUX_AMZN_ICON '\uF270'$s LINUX_ENDEAVOUROS_ICON '\UF322'$s LINUX_ROCKY_ICON '\UF32B'$s LINUX_ALMALINUX_ICON '\UF31D'$s LINUX_GUIX_ICON '\UF325'$s LINUX_NEON_ICON '\uF17C' LINUX_ICON '\uF17C' SUNOS_ICON '\uF185 ' HOME_ICON '\uF015'$s HOME_SUB_ICON '\uF07C'$s FOLDER_ICON '\uF115'$s ETC_ICON '\uF013'$s NETWORK_ICON '\UF0378'$s LOAD_ICON '\uF080 ' SWAP_ICON '\uF464'$s RAM_ICON '\uF0E4'$s SERVER_ICON '\uF0AE'$s VCS_UNTRACKED_ICON '\uF059'$s VCS_UNSTAGED_ICON '\uF06A'$s VCS_STAGED_ICON '\uF055'$s VCS_STASH_ICON '\uF01C ' VCS_INCOMING_CHANGES_ICON '\uF01A ' VCS_OUTGOING_CHANGES_ICON '\uF01B ' VCS_TAG_ICON '\uF02B ' VCS_BOOKMARK_ICON '\uF461 ' VCS_COMMIT_ICON '\uE729 ' VCS_BRANCH_ICON '\uF126 ' VCS_REMOTE_BRANCH_ICON '\uE728 ' VCS_LOADING_ICON '' VCS_GIT_ICON '\uF1D3 ' VCS_GIT_GITHUB_ICON '\uF113 ' VCS_GIT_BITBUCKET_ICON '\uE703 ' VCS_GIT_GITLAB_ICON '\uF296 ' VCS_GIT_AZURE_ICON '\uEBE8 ' VCS_GIT_ARCHLINUX_ICON '\uF303 ' VCS_GIT_CODEBERG_ICON '\uF1D3 ' VCS_GIT_DEBIAN_ICON '\uF306 ' VCS_GIT_FREEBSD_ICON '\UF30C ' VCS_GIT_FREEDESKTOP_ICON '\uF296 ' VCS_GIT_GNOME_ICON '\uF296 ' VCS_GIT_GNU_ICON '\uE779 ' VCS_GIT_KDE_ICON '\uF296 ' VCS_GIT_LINUX_ICON '\uF17C ' VCS_GIT_GITEA_ICON '\uF1D3 ' VCS_GIT_SOURCEHUT_ICON '\uF1DB ' VCS_HG_ICON '\uF0C3 ' VCS_SVN_ICON '\uE72D'$q RUST_ICON '\uE7A8'$q PYTHON_ICON '\UE73C ' CHEZMOI_ICON '\uF015'$s SWIFT_ICON '\uE755' GO_ICON '\uE626' GOLANG_ICON '\uE626' PUBLIC_IP_ICON '\UF0AC'$s LOCK_ICON '\UF023' NORDVPN_ICON '\UF023' EXECUTION_TIME_ICON '\uF252'$s SSH_ICON '\uF489'$s VPN_ICON '\UF023' KUBERNETES_ICON '\UF10FE' DROPBOX_ICON '\UF16B'$s DATE_ICON '\uF073 ' TIME_ICON '\uF017 ' JAVA_ICON '\uE738' LARAVEL_ICON '\ue73f'$q RANGER_ICON '\uF00b ' YAZI_ICON '\uF00b ' MIDNIGHT_COMMANDER_ICON 'mc' VIM_ICON '\uE62B' TERRAFORM_ICON '\uF1BB ' PROXY_ICON '\u2194' DOTNET_ICON '\uE77F' DOTNET_CORE_ICON '\uE77F' AZURE_ICON '\uEBD8 ' DIRENV_ICON '\u25BC' FLUTTER_ICON 'F' GCLOUD_ICON '\UF02AD' LUA_ICON '\uE620' PERL_ICON '\uE769' NNN_ICON 'nnn' LF_ICON 'lf' XPLR_ICON 'xplr' TIMEWARRIOR_ICON '\uF49B' TASKWARRIOR_ICON '\uF4A0 ' NIX_SHELL_ICON '\uF313 ' WIFI_ICON '\uF1EB ' ERLANG_ICON '\uE7B1 ' ELIXIR_ICON '\uE62D' POSTGRES_ICON '\uE76E' PHP_ICON '\uE608' HASKELL_ICON '\uE61F' PACKAGE_ICON '\UF03D7' JULIA_ICON '\uE624' SCALA_ICON '\uE737' TOOLBOX_ICON '\uE20F'$s ARCH_ICON '\uE266' HISTORY_ICON '\uF1DA'$s)  ;;
		('nerdfont-complete' | 'nerdfont-fontconfig') icons=(RULER_CHAR '\u2500' LEFT_SEGMENT_SEPARATOR '\uE0B0' RIGHT_SEGMENT_SEPARATOR '\uE0B2' LEFT_SEGMENT_END_SEPARATOR ' ' LEFT_SUBSEGMENT_SEPARATOR '\uE0B1' RIGHT_SUBSEGMENT_SEPARATOR '\uE0B3' CARRIAGE_RETURN_ICON '\u21B5' ROOT_ICON '\uE614'$q SUDO_ICON '\uF09C'$s RUBY_ICON '\uF219 ' AWS_ICON '\uF270'$s AWS_EB_ICON '\UF1BD'$q$q BACKGROUND_JOBS_ICON '\uF013 ' TEST_ICON '\uF188'$s TODO_ICON '\u2611' BATTERY_ICON '\UF240 ' DISK_ICON '\uF0A0'$s OK_ICON '\uF00C'$s FAIL_ICON '\uF00D' SYMFONY_ICON '\uE757' NODE_ICON '\uE617 ' NODEJS_ICON '\uE617 ' MULTILINE_FIRST_PROMPT_PREFIX '\u256D\U2500' MULTILINE_NEWLINE_PROMPT_PREFIX '\u251C\U2500' MULTILINE_LAST_PROMPT_PREFIX '\u2570\U2500 ' APPLE_ICON '\uF179' WINDOWS_ICON '\uF17A'$s FREEBSD_ICON '\UF30C ' ANDROID_ICON '\uF17B' LINUX_ARCH_ICON '\uF303' LINUX_CENTOS_ICON '\uF304'$s LINUX_COREOS_ICON '\uF305'$s LINUX_DEBIAN_ICON '\uF306' LINUX_RASPBIAN_ICON '\uF315' LINUX_ELEMENTARY_ICON '\uF309'$s LINUX_FEDORA_ICON '\uF30a'$s LINUX_GENTOO_ICON '\uF30d'$s LINUX_MAGEIA_ICON '\uF310' LINUX_MINT_ICON '\uF30e'$s LINUX_NIXOS_ICON '\uF313'$s LINUX_MANJARO_ICON '\uF312'$s LINUX_DEVUAN_ICON '\uF307'$s LINUX_ALPINE_ICON '\uF300'$s LINUX_AOSC_ICON '\uF301'$s LINUX_OPENSUSE_ICON '\uF314'$s LINUX_SABAYON_ICON '\uF317'$s LINUX_SLACKWARE_ICON '\uF319'$s LINUX_VOID_ICON '\uF17C' LINUX_ARTIX_ICON '\uF17C' LINUX_UBUNTU_ICON '\uF31b'$s LINUX_KALI_ICON '\uF17C' LINUX_RHEL_ICON '\uF316'$s LINUX_AMZN_ICON '\uF270'$s LINUX_ENDEAVOUROS_ICON '\uF17C' LINUX_ROCKY_ICON '\uF17C' LINUX_ALMALINUX_ICON '\uF17C' LINUX_GUIX_ICON '\uF325'$s LINUX_NEON_ICON '\uF17C' LINUX_ICON '\uF17C' SUNOS_ICON '\uF185 ' HOME_ICON '\uF015'$s HOME_SUB_ICON '\uF07C'$s FOLDER_ICON '\uF115'$s ETC_ICON '\uF013'$s NETWORK_ICON '\uF50D'$s LOAD_ICON '\uF080 ' SWAP_ICON '\uF464'$s RAM_ICON '\uF0E4'$s SERVER_ICON '\uF0AE'$s VCS_UNTRACKED_ICON '\uF059'$s VCS_UNSTAGED_ICON '\uF06A'$s VCS_STAGED_ICON '\uF055'$s VCS_STASH_ICON '\uF01C ' VCS_INCOMING_CHANGES_ICON '\uF01A ' VCS_OUTGOING_CHANGES_ICON '\uF01B ' VCS_TAG_ICON '\uF02B ' VCS_BOOKMARK_ICON '\uF461 ' VCS_COMMIT_ICON '\uE729 ' VCS_BRANCH_ICON '\uF126 ' VCS_REMOTE_BRANCH_ICON '\uE728 ' VCS_LOADING_ICON '' VCS_GIT_ICON '\uF1D3 ' VCS_GIT_GITHUB_ICON '\uF113 ' VCS_GIT_BITBUCKET_ICON '\uE703 ' VCS_GIT_GITLAB_ICON '\uF296 ' VCS_GIT_AZURE_ICON '\uFD03 ' VCS_GIT_ARCHLINUX_ICON '\uF303 ' VCS_GIT_CODEBERG_ICON '\uF1D3 ' VCS_GIT_DEBIAN_ICON '\uF306 ' VCS_GIT_FREEBSD_ICON '\UF30C ' VCS_GIT_FREEDESKTOP_ICON '\uF296 ' VCS_GIT_GNOME_ICON '\uF296 ' VCS_GIT_GNU_ICON '\uE779 ' VCS_GIT_KDE_ICON '\uF296 ' VCS_GIT_LINUX_ICON '\uF17C ' VCS_GIT_GITEA_ICON '\uF1D3 ' VCS_GIT_SOURCEHUT_ICON '\uF1DB ' VCS_HG_ICON '\uF0C3 ' VCS_SVN_ICON '\uE72D'$q RUST_ICON '\uE7A8'$q PYTHON_ICON '\UE73C ' CHEZMOI_ICON '\uF015'$s SWIFT_ICON '\uE755' GO_ICON '\uE626' GOLANG_ICON '\uE626' PUBLIC_IP_ICON '\UF0AC'$s LOCK_ICON '\UF023' NORDVPN_ICON '\UF023' EXECUTION_TIME_ICON '\uF252'$s SSH_ICON '\uF489'$s VPN_ICON '\UF023' KUBERNETES_ICON '\U2388' DROPBOX_ICON '\UF16B'$s DATE_ICON '\uF073 ' TIME_ICON '\uF017 ' JAVA_ICON '\uE738' LARAVEL_ICON '\ue73f'$q RANGER_ICON '\uF00b ' YAZI_ICON '\uF00b ' MIDNIGHT_COMMANDER_ICON 'mc' VIM_ICON '\uE62B' TERRAFORM_ICON '\uF1BB ' PROXY_ICON '\u2194' DOTNET_ICON '\uE77F' DOTNET_CORE_ICON '\uE77F' AZURE_ICON '\uFD03' DIRENV_ICON '\u25BC' FLUTTER_ICON 'F' GCLOUD_ICON '\uF7B7' LUA_ICON '\uE620' PERL_ICON '\uE769' NNN_ICON 'nnn' LF_ICON 'lf' XPLR_ICON 'xplr' TIMEWARRIOR_ICON '\uF49B' TASKWARRIOR_ICON '\uF4A0 ' NIX_SHELL_ICON '\uF313 ' WIFI_ICON '\uF1EB ' ERLANG_ICON '\uE7B1 ' ELIXIR_ICON '\uE62D' POSTGRES_ICON '\uE76E' PHP_ICON '\uE608' HASKELL_ICON '\uE61F' PACKAGE_ICON '\uF8D6' JULIA_ICON '\uE624' SCALA_ICON '\uE737' TOOLBOX_ICON '\uE20F'$s ARCH_ICON '\uE266' HISTORY_ICON '\uF1DA'$s)  ;;
		(ascii) icons=(RULER_CHAR '-' LEFT_SEGMENT_SEPARATOR '' RIGHT_SEGMENT_SEPARATOR '' LEFT_SEGMENT_END_SEPARATOR ' ' LEFT_SUBSEGMENT_SEPARATOR '|' RIGHT_SUBSEGMENT_SEPARATOR '|' CARRIAGE_RETURN_ICON '' ROOT_ICON '#' SUDO_ICON '' RUBY_ICON 'rb' AWS_ICON 'aws' AWS_EB_ICON 'eb' BACKGROUND_JOBS_ICON '%%' TEST_ICON '' TODO_ICON 'todo' BATTERY_ICON 'battery' DISK_ICON 'disk' OK_ICON 'ok' FAIL_ICON 'err' SYMFONY_ICON 'symphony' NODE_ICON 'node' NODEJS_ICON 'node' MULTILINE_FIRST_PROMPT_PREFIX '' MULTILINE_NEWLINE_PROMPT_PREFIX '' MULTILINE_LAST_PROMPT_PREFIX '' APPLE_ICON 'mac' WINDOWS_ICON 'win' FREEBSD_ICON 'bsd' ANDROID_ICON 'android' LINUX_ICON 'linux' LINUX_ARCH_ICON 'arch' LINUX_DEBIAN_ICON 'debian' LINUX_RASPBIAN_ICON 'pi' LINUX_UBUNTU_ICON 'ubuntu' LINUX_KALI_ICON 'kali' LINUX_CENTOS_ICON 'centos' LINUX_COREOS_ICON 'coreos' LINUX_ELEMENTARY_ICON 'elementary' LINUX_MINT_ICON 'mint' LINUX_FEDORA_ICON 'fedora' LINUX_GENTOO_ICON 'gentoo' LINUX_MAGEIA_ICON 'mageia' LINUX_NIXOS_ICON 'nixos' LINUX_MANJARO_ICON 'manjaro' LINUX_DEVUAN_ICON 'devuan' LINUX_ALPINE_ICON 'alpine' LINUX_AOSC_ICON 'aosc' LINUX_OPENSUSE_ICON 'suse' LINUX_SABAYON_ICON 'sabayon' LINUX_SLACKWARE_ICON 'slack' LINUX_VOID_ICON 'void' LINUX_ARTIX_ICON 'artix' LINUX_RHEL_ICON 'rhel' LINUX_AMZN_ICON 'amzn' LINUX_ENDEAVOUROS_ICON 'edvos' LINUX_ROCKY_ICON 'rocky' LINUX_ALMALINUX_ICON 'alma' LINUX_GUIX_ICON 'guix' LINUX_NEON_ICON 'neon' SUNOS_ICON 'sunos' HOME_ICON '' HOME_SUB_ICON '' FOLDER_ICON '' ETC_ICON '' NETWORK_ICON 'ip' LOAD_ICON 'cpu' SWAP_ICON 'swap' RAM_ICON 'ram' SERVER_ICON '' VCS_UNTRACKED_ICON '?' VCS_UNSTAGED_ICON '!' VCS_STAGED_ICON '+' VCS_STASH_ICON '#' VCS_INCOMING_CHANGES_ICON '<' VCS_OUTGOING_CHANGES_ICON '>' VCS_TAG_ICON '' VCS_BOOKMARK_ICON '^' VCS_COMMIT_ICON '@' VCS_BRANCH_ICON '' VCS_REMOTE_BRANCH_ICON ':' VCS_LOADING_ICON '' VCS_GIT_ICON '' VCS_GIT_GITHUB_ICON '' VCS_GIT_BITBUCKET_ICON '' VCS_GIT_GITLAB_ICON '' VCS_GIT_AZURE_ICON '' VCS_GIT_ARCHLINUX_ICON '' VCS_GIT_CODEBERG_ICON '' VCS_GIT_DEBIAN_ICON '' VCS_GIT_FREEBSD_ICON '' VCS_GIT_FREEDESKTOP_ICON '' VCS_GIT_GNOME_ICON '' VCS_GIT_GNU_ICON '' VCS_GIT_KDE_ICON '' VCS_GIT_LINUX_ICON '' VCS_GIT_GITEA_ICON '' VCS_GIT_SOURCEHUT_ICON '' VCS_HG_ICON '' VCS_SVN_ICON '' RUST_ICON 'rust' PYTHON_ICON 'py' CHEZMOI_ICON 'chezmoi' SWIFT_ICON 'swift' GO_ICON 'go' GOLANG_ICON 'go' PUBLIC_IP_ICON 'ip' LOCK_ICON '!w' NORDVPN_ICON 'nordvpn' EXECUTION_TIME_ICON '' SSH_ICON 'ssh' VPN_ICON 'vpn' KUBERNETES_ICON 'kube' DROPBOX_ICON 'dropbox' DATE_ICON '' TIME_ICON '' JAVA_ICON 'java' LARAVEL_ICON '' RANGER_ICON 'ranger' YAZI_ICON 'yazi' MIDNIGHT_COMMANDER_ICON 'mc' VIM_ICON 'vim' TERRAFORM_ICON 'tf' PROXY_ICON 'proxy' DOTNET_ICON '.net' DOTNET_CORE_ICON '.net' AZURE_ICON 'az' DIRENV_ICON 'direnv' FLUTTER_ICON 'flutter' GCLOUD_ICON 'gcloud' LUA_ICON 'lua' PERL_ICON 'perl' NNN_ICON 'nnn' LF_ICON 'lf' XPLR_ICON 'xplr' TIMEWARRIOR_ICON 'tw' TASKWARRIOR_ICON 'task' NIX_SHELL_ICON 'nix' WIFI_ICON 'wifi' ERLANG_ICON 'erlang' ELIXIR_ICON 'elixir' POSTGRES_ICON 'postgres' PHP_ICON 'php' HASKELL_ICON 'hs' PACKAGE_ICON 'pkg' JULIA_ICON 'jl' SCALA_ICON 'scala' TOOLBOX_ICON 'toolbox' ARCH_ICON 'arch' HISTORY_ICON 'hist')  ;;
		(*) icons=(RULER_CHAR '\u2500' LEFT_SEGMENT_SEPARATOR '\uE0B0' RIGHT_SEGMENT_SEPARATOR '\uE0B2' LEFT_SEGMENT_END_SEPARATOR ' ' LEFT_SUBSEGMENT_SEPARATOR '\uE0B1' RIGHT_SUBSEGMENT_SEPARATOR '\uE0B3' CARRIAGE_RETURN_ICON '\u21B5' ROOT_ICON '\u26A1' SUDO_ICON '' RUBY_ICON 'Ruby' AWS_ICON 'AWS' AWS_EB_ICON '\U1F331'$q BACKGROUND_JOBS_ICON '\u2699' TEST_ICON '' TODO_ICON '\u2206' BATTERY_ICON '\U1F50B' DISK_ICON 'hdd' OK_ICON '\u2714' FAIL_ICON '\u2718' SYMFONY_ICON 'SF' NODE_ICON 'Node' NODEJS_ICON 'Node' MULTILINE_FIRST_PROMPT_PREFIX '\u256D\U2500' MULTILINE_NEWLINE_PROMPT_PREFIX '\u251C\U2500' MULTILINE_LAST_PROMPT_PREFIX '\u2570\U2500 ' APPLE_ICON 'OSX' WINDOWS_ICON 'WIN' FREEBSD_ICON 'BSD' ANDROID_ICON 'And' LINUX_ICON 'Lx' LINUX_ARCH_ICON 'Arc' LINUX_DEBIAN_ICON 'Deb' LINUX_RASPBIAN_ICON 'RPi' LINUX_UBUNTU_ICON 'Ubu' LINUX_KALI_ICON 'Kal' LINUX_CENTOS_ICON 'Cen' LINUX_COREOS_ICON 'Cor' LINUX_ELEMENTARY_ICON 'Elm' LINUX_MINT_ICON 'LMi' LINUX_FEDORA_ICON 'Fed' LINUX_GENTOO_ICON 'Gen' LINUX_MAGEIA_ICON 'Mag' LINUX_NIXOS_ICON 'Nix' LINUX_MANJARO_ICON 'Man' LINUX_DEVUAN_ICON 'Dev' LINUX_ALPINE_ICON 'Alp' LINUX_AOSC_ICON 'Aos' LINUX_OPENSUSE_ICON 'OSu' LINUX_SABAYON_ICON 'Sab' LINUX_SLACKWARE_ICON 'Sla' LINUX_VOID_ICON 'Vo' LINUX_ARTIX_ICON 'Art' LINUX_RHEL_ICON 'RH' LINUX_AMZN_ICON 'Amzn' LINUX_ENDEAVOUROS_ICON 'Edv' LINUX_ROCKY_ICON 'Roc' LINUX_ALMALINUX_ICON 'Alma' LINUX_GUIX_ICON 'Guix' LINUX_NEON_ICON 'Neon' SUNOS_ICON 'Sun' HOME_ICON '' HOME_SUB_ICON '' FOLDER_ICON '' ETC_ICON '\u2699' NETWORK_ICON 'IP' LOAD_ICON 'L' SWAP_ICON 'SWP' RAM_ICON 'RAM' SERVER_ICON '' VCS_UNTRACKED_ICON '?' VCS_UNSTAGED_ICON '\u25CF' VCS_STAGED_ICON '\u271A' VCS_STASH_ICON '\u235F' VCS_INCOMING_CHANGES_ICON '\u2193' VCS_OUTGOING_CHANGES_ICON '\u2191' VCS_TAG_ICON '' VCS_BOOKMARK_ICON '\u263F' VCS_COMMIT_ICON '' VCS_BRANCH_ICON '\uE0A0 ' VCS_REMOTE_BRANCH_ICON '\u2192' VCS_LOADING_ICON '' VCS_GIT_ICON '' VCS_GIT_GITHUB_ICON '' VCS_GIT_BITBUCKET_ICON '' VCS_GIT_GITLAB_ICON '' VCS_GIT_AZURE_ICON '' VCS_GIT_ARCHLINUX_ICON '' VCS_GIT_CODEBERG_ICON '' VCS_GIT_DEBIAN_ICON '' VCS_GIT_FREEBSD_ICON '' VCS_GIT_FREEDESKTOP_ICON '' VCS_GIT_GNOME_ICON '' VCS_GIT_GNU_ICON '' VCS_GIT_KDE_ICON '' VCS_GIT_LINUX_ICON '' VCS_GIT_GITEA_ICON '' VCS_GIT_SOURCEHUT_ICON '' VCS_HG_ICON '' VCS_SVN_ICON '' RUST_ICON 'R' PYTHON_ICON 'Py' CHEZMOI_ICON 'Chez' SWIFT_ICON 'Swift' GO_ICON 'Go' GOLANG_ICON 'Go' PUBLIC_IP_ICON 'IP' LOCK_ICON '\UE0A2' NORDVPN_ICON '\UE0A2' EXECUTION_TIME_ICON '' SSH_ICON 'ssh' VPN_ICON 'vpn' KUBERNETES_ICON '\U2388' DROPBOX_ICON 'Dropbox' DATE_ICON '' TIME_ICON '' JAVA_ICON '\U2615' LARAVEL_ICON '' RANGER_ICON '\u2B50' YAZI_ICON '\u2B50' MIDNIGHT_COMMANDER_ICON 'mc' VIM_ICON 'vim' TERRAFORM_ICON 'tf' PROXY_ICON '\u2194' DOTNET_ICON '.NET' DOTNET_CORE_ICON '.NET' AZURE_ICON '\u2601' DIRENV_ICON '\u25BC' FLUTTER_ICON 'F' GCLOUD_ICON 'G' LUA_ICON 'lua' PERL_ICON 'perl' NNN_ICON 'nnn' LF_ICON 'lf' XPLR_ICON 'xplr' TIMEWARRIOR_ICON 'tw' TASKWARRIOR_ICON 'task' NIX_SHELL_ICON 'nix' WIFI_ICON 'WiFi' ERLANG_ICON 'erl' ELIXIR_ICON 'elixir' POSTGRES_ICON 'postgres' PHP_ICON 'php' HASKELL_ICON 'hs' PACKAGE_ICON 'pkg' JULIA_ICON 'jl' SCALA_ICON 'scala' TOOLBOX_ICON '\u2B22' ARCH_ICON 'arch' HISTORY_ICON 'hist')  ;;
	esac
	case $POWERLEVEL9K_MODE in
		('flat') icons[LEFT_SEGMENT_SEPARATOR]='' 
			icons[RIGHT_SEGMENT_SEPARATOR]='' 
			icons[LEFT_SUBSEGMENT_SEPARATOR]='|' 
			icons[RIGHT_SUBSEGMENT_SEPARATOR]='|'  ;;
		('compatible') icons[LEFT_SEGMENT_SEPARATOR]='\u2B80' 
			icons[RIGHT_SEGMENT_SEPARATOR]='\u2B82' 
			icons[VCS_BRANCH_ICON]='@'  ;;
	esac
	if [[ $POWERLEVEL9K_ICON_PADDING == none && $POWERLEVEL9K_MODE != ascii ]]
	then
		icons=("${(@kv)icons%% #}") 
		icons[LEFT_SEGMENT_END_SEPARATOR]+=' ' 
		icons[MULTILINE_LAST_PROMPT_PREFIX]+=' ' 
		icons[VCS_TAG_ICON]+=' ' 
		icons[VCS_BOOKMARK_ICON]+=' ' 
		icons[VCS_COMMIT_ICON]+=' ' 
		icons[VCS_BRANCH_ICON]+=' ' 
		icons[VCS_REMOTE_BRANCH_ICON]+=' ' 
	fi
}
_p9k_init_lines () {
	local -a left_segments=($_POWERLEVEL9K_LEFT_PROMPT_ELEMENTS) 
	local -a right_segments=($_POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS) 
	if (( _POWERLEVEL9K_PROMPT_ON_NEWLINE ))
	then
		left_segments+=(newline _p9k_internal_nothing) 
	fi
	local -i num_left_lines=$((1 + ${#${(@M)left_segments:#newline}})) 
	local -i num_right_lines=$((1 + ${#${(@M)right_segments:#newline}})) 
	if (( num_right_lines > num_left_lines ))
	then
		repeat $((num_right_lines - num_left_lines))
		do
			left_segments=(newline $left_segments) 
		done
		local -i num_lines=num_right_lines 
	else
		if (( _POWERLEVEL9K_RPROMPT_ON_NEWLINE ))
		then
			repeat $((num_left_lines - num_right_lines))
			do
				right_segments=(newline $right_segments) 
			done
		else
			repeat $((num_left_lines - num_right_lines))
			do
				right_segments+=newline 
			done
		fi
		local -i num_lines=num_left_lines 
	fi
	local -i i
	for i in {1..$num_lines}
	do
		local -i left_end=${left_segments[(i)newline]} 
		local -i right_end=${right_segments[(i)newline]} 
		_p9k_line_segments_left+="${(pj:\0:)left_segments[1,left_end-1]}" 
		_p9k_line_segments_right+="${(pj:\0:)right_segments[1,right_end-1]}" 
		(( left_end > $#left_segments )) && left_segments=()  || shift left_end left_segments
		(( right_end > $#right_segments )) && right_segments=()  || shift right_end right_segments
		_p9k_get_icon '' LEFT_SEGMENT_SEPARATOR
		_p9k_get_icon 'prompt_empty_line' LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL $_p9k__ret
		_p9k_escape $_p9k__ret
		_p9k_line_prefix_left+='${_p9k__'$i'l-${${:-${_p9k__bg::=NONE}${_p9k__i::=0}${_p9k__sss::=%f'$_p9k__ret'}}+}' 
		_p9k_line_suffix_left+='%b%k$_p9k__sss%b%k%f' 
		_p9k_escape ${(g::)_POWERLEVEL9K_EMPTY_LINE_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL}
		[[ -n $_p9k__ret ]] && _p9k_line_never_empty_right+=1  || _p9k_line_never_empty_right+=0 
		_p9k_line_prefix_right+='${_p9k__'$i'r-${${:-${_p9k__bg::=NONE}${_p9k__i::=0}${_p9k__sss::='$_p9k__ret'}}+}' 
		_p9k_line_suffix_right+='$_p9k__sss%b%k%f}' 
		if (( i == num_lines ))
		then
			_p9k_prompt_length ${(e)_p9k__ret}
			(( _p9k__ret )) || _p9k_line_never_empty_right[-1]=0 
		fi
	done
	_p9k_get_icon '' LEFT_SEGMENT_END_SEPARATOR
	if [[ -n $_p9k__ret ]]
	then
		_p9k__ret+=%b%k%f 
		_p9k__ret='${:-"'$_p9k__ret'"}' 
		if (( _POWERLEVEL9K_PROMPT_ON_NEWLINE ))
		then
			_p9k_line_suffix_left[-2]+=$_p9k__ret 
		else
			_p9k_line_suffix_left[-1]+=$_p9k__ret 
		fi
	fi
	for i in {1..$num_lines}
	do
		_p9k_line_suffix_left[i]+='}' 
	done
	if (( num_lines > 1 ))
	then
		for i in {1..$((num_lines-1))}
		do
			_p9k_build_gap_post $i
			_p9k_line_gap_post+=$_p9k__ret 
		done
		if [[ $+_POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX == 1 || $_POWERLEVEL9K_PROMPT_ON_NEWLINE == 1 ]]
		then
			_p9k_get_icon '' MULTILINE_FIRST_PROMPT_PREFIX
			if [[ -n $_p9k__ret ]]
			then
				[[ _p9k__ret == *%* ]] && _p9k__ret+=%b%k%f 
				_p9k__ret='${_p9k__1l_frame-"'$_p9k__ret'"}' 
				_p9k_line_prefix_left[1]=$_p9k__ret$_p9k_line_prefix_left[1] 
			fi
		fi
		if [[ $+_POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX == 1 || $_POWERLEVEL9K_PROMPT_ON_NEWLINE == 1 ]]
		then
			_p9k_get_icon '' MULTILINE_LAST_PROMPT_PREFIX
			if [[ -n $_p9k__ret ]]
			then
				[[ _p9k__ret == *%* ]] && _p9k__ret+=%b%k%f 
				_p9k__ret='${_p9k__'$num_lines'l_frame-"'$_p9k__ret'"}' 
				_p9k_line_prefix_left[-1]=$_p9k__ret$_p9k_line_prefix_left[-1] 
			fi
		fi
		_p9k_get_icon '' MULTILINE_FIRST_PROMPT_SUFFIX
		if [[ -n $_p9k__ret ]]
		then
			[[ _p9k__ret == *%* ]] && _p9k__ret+=%b%k%f 
			_p9k_line_suffix_right[1]+='${_p9k__1r_frame-'${(qqq)_p9k__ret}'}' 
			_p9k_line_never_empty_right[1]=1 
		fi
		_p9k_get_icon '' MULTILINE_LAST_PROMPT_SUFFIX
		if [[ -n $_p9k__ret ]]
		then
			[[ _p9k__ret == *%* ]] && _p9k__ret+=%b%k%f 
			_p9k_line_suffix_right[-1]+='${_p9k__'$num_lines'r_frame-'${(qqq)_p9k__ret}'}' 
			_p9k_prompt_length $_p9k__ret
			(( _p9k__ret )) && _p9k_line_never_empty_right[-1]=1 
		fi
		if (( num_lines > 2 ))
		then
			if [[ $+_POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX == 1 || $_POWERLEVEL9K_PROMPT_ON_NEWLINE == 1 ]]
			then
				_p9k_get_icon '' MULTILINE_NEWLINE_PROMPT_PREFIX
				if [[ -n $_p9k__ret ]]
				then
					[[ _p9k__ret == *%* ]] && _p9k__ret+=%b%k%f 
					for i in {2..$((num_lines-1))}
					do
						_p9k_line_prefix_left[i]='${_p9k__'$i'l_frame-"'$_p9k__ret'"}'$_p9k_line_prefix_left[i] 
					done
				fi
			fi
			_p9k_get_icon '' MULTILINE_NEWLINE_PROMPT_SUFFIX
			if [[ -n $_p9k__ret ]]
			then
				[[ _p9k__ret == *%* ]] && _p9k__ret+=%b%k%f 
				for i in {2..$((num_lines-1))}
				do
					_p9k_line_suffix_right[i]+='${_p9k__'$i'r_frame-'${(qqq)_p9k__ret}'}' 
				done
				_p9k_line_never_empty_right[2,-2]=${(@)_p9k_line_never_empty_right[2,-2]/0/1} 
			fi
		fi
	fi
}
_p9k_init_locale () {
	if (( ! $+__p9k_locale ))
	then
		typeset -g __p9k_locale= 
		(( $+commands[locale] )) || return
		local -a loc
		loc=(${(@M)$(locale -a 2>/dev/null):#*.(utf|UTF)(-|)8})  || return
		(( $#loc )) || return
		typeset -g __p9k_locale=${loc[(r)(#i)C.UTF(-|)8]:-${loc[(r)(#i)en_US.UTF(-|)8]:-$loc[1]}} 
	fi
	[[ -n $__p9k_locale ]]
}
_p9k_init_params () {
	_p9k_declare -F POWERLEVEL9K_GCLOUD_REFRESH_PROJECT_NAME_SECONDS 60
	_p9k_declare -s POWERLEVEL9K_INSTANT_PROMPT
	if [[ $_POWERLEVEL9K_INSTANT_PROMPT == off ]]
	then
		typeset -gi _POWERLEVEL9K_DISABLE_INSTANT_PROMPT=1 
	else
		_p9k_declare -b POWERLEVEL9K_DISABLE_INSTANT_PROMPT 0
		if (( _POWERLEVEL9K_DISABLE_INSTANT_PROMPT ))
		then
			_POWERLEVEL9K_INSTANT_PROMPT=off 
		elif [[ $_POWERLEVEL9K_INSTANT_PROMPT != quiet ]]
		then
			_POWERLEVEL9K_INSTANT_PROMPT=verbose 
		fi
	fi
	(( _POWERLEVEL9K_DISABLE_INSTANT_PROMPT )) && _p9k__instant_prompt_disabled=1 
	_p9k_declare -s POWERLEVEL9K_TRANSIENT_PROMPT off
	[[ $_POWERLEVEL9K_TRANSIENT_PROMPT == (off|always|same-dir) ]] || _POWERLEVEL9K_TRANSIENT_PROMPT=off 
	_p9k_declare -b POWERLEVEL9K_TERM_SHELL_INTEGRATION 0
	if [[ __p9k_force_term_shell_integration -eq 1 || $ITERM_SHELL_INTEGRATION_INSTALLED == Yes ]]
	then
		_POWERLEVEL9K_TERM_SHELL_INTEGRATION=1 
	fi
	_p9k_declare -s POWERLEVEL9K_WORKER_LOG_LEVEL
	_p9k_declare -i POWERLEVEL9K_COMMANDS_MAX_TOKEN_COUNT 64
	_p9k_declare -a POWERLEVEL9K_HOOK_WIDGETS --
	_p9k_declare -b POWERLEVEL9K_TODO_HIDE_ZERO_TOTAL 0
	_p9k_declare -b POWERLEVEL9K_TODO_HIDE_ZERO_FILTERED 0
	_p9k_declare -b POWERLEVEL9K_DISABLE_HOT_RELOAD 0
	_p9k_declare -F POWERLEVEL9K_NEW_TTY_MAX_AGE_SECONDS 5
	_p9k_declare -i POWERLEVEL9K_INSTANT_PROMPT_COMMAND_LINES
	_p9k_declare -a POWERLEVEL9K_LEFT_PROMPT_ELEMENTS -- context dir vcs
	_p9k_declare -a POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS -- status root_indicator background_jobs history time
	_p9k_declare -b POWERLEVEL9K_DISABLE_RPROMPT 0
	_p9k_declare -b POWERLEVEL9K_PROMPT_ADD_NEWLINE 0
	_p9k_declare -b POWERLEVEL9K_PROMPT_ON_NEWLINE 0
	_p9k_declare -b POWERLEVEL9K_RPROMPT_ON_NEWLINE 0
	_p9k_declare -b POWERLEVEL9K_SHOW_RULER 0
	_p9k_declare -i POWERLEVEL9K_PROMPT_ADD_NEWLINE_COUNT 1
	_p9k_declare -s POWERLEVEL9K_COLOR_SCHEME dark
	_p9k_declare -s POWERLEVEL9K_GITSTATUS_DIR ""
	_p9k_declare -s POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN
	_p9k_declare -b POWERLEVEL9K_VCS_SHOW_SUBMODULE_DIRTY 0
	_p9k_declare -i POWERLEVEL9K_VCS_SHORTEN_LENGTH
	_p9k_declare -i POWERLEVEL9K_VCS_SHORTEN_MIN_LENGTH
	_p9k_declare -s POWERLEVEL9K_VCS_SHORTEN_STRATEGY
	if [[ $langinfo[CODESET] == (utf|UTF)(-|)8 ]]
	then
		_p9k_declare -e POWERLEVEL9K_VCS_SHORTEN_DELIMITER '\u2026'
	else
		_p9k_declare -e POWERLEVEL9K_VCS_SHORTEN_DELIMITER '..'
	fi
	_p9k_declare -b POWERLEVEL9K_VCS_CONFLICTED_STATE 0
	_p9k_declare -b POWERLEVEL9K_HIDE_BRANCH_ICON 0
	_p9k_declare -b POWERLEVEL9K_VCS_HIDE_TAGS 0
	_p9k_declare -a POWERLEVEL9K_VCS_GIT_REMOTE_ICONS
	if (( $+_POWERLEVEL9K_VCS_GIT_REMOTE_ICONS ))
	then
		(( $#_POWERLEVEL9K_VCS_GIT_REMOTE_ICONS & 1 )) && _POWERLEVEL9K_VCS_GIT_REMOTE_ICONS+=('') 
	else
		local domain= icon= domain2icon=('archlinux.org' VCS_GIT_ARCHLINUX_ICON 'dev.azure.com|visualstudio.com' VCS_GIT_AZURE_ICON 'bitbucket.org' VCS_GIT_BITBUCKET_ICON 'codeberg.org' VCS_GIT_CODEBERG_ICON 'debian.org' VCS_GIT_DEBIAN_ICON 'freebsd.org' VCS_GIT_FREEBSD_ICON 'freedesktop.org' VCS_GIT_FREEDESKTOP_ICON 'gitea.com|gitea.io' VCS_GIT_GITEA_ICON 'github.com' VCS_GIT_GITHUB_ICON 'gitlab.com' VCS_GIT_GITLAB_ICON 'gnome.org' VCS_GIT_GNOME_ICON 'gnu.org' VCS_GIT_GNU_ICON 'kde.org' VCS_GIT_KDE_ICON 'kernel.org' VCS_GIT_LINUX_ICON 'sr.ht' VCS_GIT_SOURCEHUT_ICON) 
		typeset -ga _POWERLEVEL9K_VCS_GIT_REMOTE_ICONS
		for domain icon in "${domain2icon[@]}"
		do
			_POWERLEVEL9K_VCS_GIT_REMOTE_ICONS+=('(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)'$domain')(|[/:?#]*)' $icon) 
		done
		_POWERLEVEL9K_VCS_GIT_REMOTE_ICONS+=('*' VCS_GIT_ICON) 
	fi
	_p9k_declare -i POWERLEVEL9K_CHANGESET_HASH_LENGTH 8
	_p9k_declare -i POWERLEVEL9K_MAX_CACHE_SIZE 10000
	_p9k_declare -e POWERLEVEL9K_ANACONDA_LEFT_DELIMITER "("
	_p9k_declare -e POWERLEVEL9K_ANACONDA_RIGHT_DELIMITER ")"
	_p9k_declare -b POWERLEVEL9K_ANACONDA_SHOW_PYTHON_VERSION 1
	_p9k_declare -b POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE 1
	_p9k_declare -b POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE_ALWAYS 0
	_p9k_declare -b POWERLEVEL9K_DISK_USAGE_ONLY_WARNING 0
	_p9k_declare -i POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL 90
	_p9k_declare -i POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL 95
	_p9k_declare -i POWERLEVEL9K_BATTERY_LOW_THRESHOLD 10
	_p9k_declare -i POWERLEVEL9K_BATTERY_HIDE_ABOVE_THRESHOLD 999
	_p9k_declare -b POWERLEVEL9K_BATTERY_VERBOSE 1
	_p9k_declare -a POWERLEVEL9K_BATTERY_LEVEL_BACKGROUND --
	_p9k_declare -a POWERLEVEL9K_BATTERY_LEVEL_FOREGROUND --
	case $parameters[POWERLEVEL9K_BATTERY_STAGES] in
		(scalar*) typeset -ga _POWERLEVEL9K_BATTERY_STAGES=("${(@s::)${(g::)POWERLEVEL9K_BATTERY_STAGES}}")  ;;
		(array*) typeset -ga _POWERLEVEL9K_BATTERY_STAGES=("${(@g::)POWERLEVEL9K_BATTERY_STAGES}")  ;;
		(*) typeset -ga _POWERLEVEL9K_BATTERY_STAGES=()  ;;
	esac
	local state
	for state in CHARGED CHARGING LOW DISCONNECTED
	do
		_p9k_declare -i POWERLEVEL9K_BATTERY_${state}_HIDE_ABOVE_THRESHOLD $_POWERLEVEL9K_BATTERY_HIDE_ABOVE_THRESHOLD
		local var=POWERLEVEL9K_BATTERY_${state}_STAGES 
		case $parameters[$var] in
			(scalar*) eval "typeset -ga _$var=(${(@qq)${(@s::)${(g::)${(P)var}}}})" ;;
			(array*) eval "typeset -ga _$var=(${(@qq)${(@g::)${(@P)var}}})" ;;
			(*) eval "typeset -ga _$var=(${(@qq)_POWERLEVEL9K_BATTERY_STAGES})" ;;
		esac
		local var=POWERLEVEL9K_BATTERY_${state}_LEVEL_BACKGROUND 
		case $parameters[$var] in
			(array*) eval "typeset -ga _$var=(${(@qq)${(@P)var}})" ;;
			(*) eval "typeset -ga _$var=(${(@qq)_POWERLEVEL9K_BATTERY_LEVEL_BACKGROUND})" ;;
		esac
		local var=POWERLEVEL9K_BATTERY_${state}_LEVEL_FOREGROUND 
		case $parameters[$var] in
			(array*) eval "typeset -ga _$var=(${(@qq)${(@P)var}})" ;;
			(*) eval "typeset -ga _$var=(${(@qq)_POWERLEVEL9K_BATTERY_LEVEL_FOREGROUND})" ;;
		esac
	done
	_p9k_declare -F POWERLEVEL9K_PUBLIC_IP_TIMEOUT 300
	_p9k_declare -a POWERLEVEL9K_PUBLIC_IP_METHODS -- dig curl wget
	_p9k_declare -e POWERLEVEL9K_PUBLIC_IP_NONE ""
	_p9k_declare -s POWERLEVEL9K_PUBLIC_IP_HOST "https://v4.ident.me/"
	_p9k_declare -s POWERLEVEL9K_PUBLIC_IP_VPN_INTERFACE ""
	_p9k_segment_in_use public_ip || _POWERLEVEL9K_PUBLIC_IP_VPN_INTERFACE= 
	_p9k_declare -b POWERLEVEL9K_ALWAYS_SHOW_CONTEXT 0
	_p9k_declare -b POWERLEVEL9K_ALWAYS_SHOW_USER 0
	_p9k_declare -e POWERLEVEL9K_CONTEXT_TEMPLATE "%n@%m"
	_p9k_declare -e POWERLEVEL9K_USER_TEMPLATE "%n"
	_p9k_declare -e POWERLEVEL9K_HOST_TEMPLATE "%m"
	_p9k_declare -F POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD 3
	_p9k_declare -i POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION 2
	_p9k_declare -s POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT "H:M:S"
	_p9k_declare -e POWERLEVEL9K_HOME_FOLDER_ABBREVIATION "~"
	_p9k_declare -b POWERLEVEL9K_DIR_PATH_ABSOLUTE 0
	_p9k_declare -s POWERLEVEL9K_DIR_SHOW_WRITABLE ''
	case $_POWERLEVEL9K_DIR_SHOW_WRITABLE in
		(true) _POWERLEVEL9K_DIR_SHOW_WRITABLE=1  ;;
		(v2) _POWERLEVEL9K_DIR_SHOW_WRITABLE=2  ;;
		(v3) _POWERLEVEL9K_DIR_SHOW_WRITABLE=3  ;;
		(*) _POWERLEVEL9K_DIR_SHOW_WRITABLE=0  ;;
	esac
	typeset -gi _POWERLEVEL9K_DIR_SHOW_WRITABLE
	_p9k_declare -b POWERLEVEL9K_DIR_OMIT_FIRST_CHARACTER 0
	_p9k_declare -b POWERLEVEL9K_DIR_HYPERLINK 0
	_p9k_declare -s POWERLEVEL9K_SHORTEN_STRATEGY ""
	local markers=(.bzr .citc .git .hg .node-version .python-version .ruby-version .shorten_folder_marker .svn .terraform CVS Cargo.toml composer.json go.mod package.json) 
	_p9k_declare -s POWERLEVEL9K_SHORTEN_FOLDER_MARKER "(${(j:|:)markers})"
	_p9k_declare -s POWERLEVEL9K_DIR_MAX_LENGTH 0
	_p9k_declare -a POWERLEVEL9K_DIR_PACKAGE_FILES -- package.json composer.json
	_p9k_declare -i POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS 40
	_p9k_declare -F POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT 50
	_p9k_declare -a POWERLEVEL9K_DIR_CLASSES
	_p9k_declare -i POWERLEVEL9K_SHORTEN_DELIMITER_LENGTH
	_p9k_declare -e POWERLEVEL9K_SHORTEN_DELIMITER
	_p9k_declare -s POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER ''
	case $_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER in
		(first | last) _POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER+=:0  ;;
		((first|last):(|-)<->)  ;;
		(*) _POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=  ;;
	esac
	[[ -z $_POWERLEVEL9K_SHORTEN_FOLDER_MARKER ]] && _POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER= 
	_p9k_declare -i POWERLEVEL9K_SHORTEN_DIR_LENGTH
	_p9k_declare -s POWERLEVEL9K_IP_INTERFACE ""
	: ${_POWERLEVEL9K_IP_INTERFACE:='.*'}
	_p9k_segment_in_use ip || _POWERLEVEL9K_IP_INTERFACE= 
	_p9k_declare -s POWERLEVEL9K_VPN_IP_INTERFACE "(gpd|wg|(.*tun)|tailscale)[0-9]*|(zt.*)"
	: ${_POWERLEVEL9K_VPN_IP_INTERFACE:='.*'}
	_p9k_segment_in_use vpn_ip || _POWERLEVEL9K_VPN_IP_INTERFACE= 
	_p9k_declare -b POWERLEVEL9K_VPN_IP_SHOW_ALL 0
	_p9k_declare -i POWERLEVEL9K_LOAD_WHICH 5
	case $_POWERLEVEL9K_LOAD_WHICH in
		(1) _POWERLEVEL9K_LOAD_WHICH=1  ;;
		(15) _POWERLEVEL9K_LOAD_WHICH=3  ;;
		(*) _POWERLEVEL9K_LOAD_WHICH=2  ;;
	esac
	_p9k_declare -F POWERLEVEL9K_LOAD_WARNING_PCT 50
	_p9k_declare -F POWERLEVEL9K_LOAD_CRITICAL_PCT 70
	_p9k_declare -b POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY 0
	_p9k_declare -b POWERLEVEL9K_PHP_VERSION_PROJECT_ONLY 0
	_p9k_declare -b POWERLEVEL9K_DOTNET_VERSION_PROJECT_ONLY 1
	_p9k_declare -b POWERLEVEL9K_GO_VERSION_PROJECT_ONLY 1
	_p9k_declare -b POWERLEVEL9K_RUST_VERSION_PROJECT_ONLY 1
	_p9k_declare -b POWERLEVEL9K_PERLBREW_PROJECT_ONLY 1
	_p9k_declare -b POWERLEVEL9K_PERLBREW_SHOW_PREFIX 0
	_p9k_declare -b POWERLEVEL9K_JAVA_VERSION_PROJECT_ONLY 0
	_p9k_declare -b POWERLEVEL9K_NODENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -a POWERLEVEL9K_NODENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_NODENV_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_NVM_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -b POWERLEVEL9K_NVM_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -a POWERLEVEL9K_RBENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_RBENV_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_SCALAENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -a POWERLEVEL9K_SCALAENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_SCALAENV_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_PHPENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -a POWERLEVEL9K_PHPENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_PHPENV_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_LUAENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -a POWERLEVEL9K_LUAENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_LUAENV_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_JENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -a POWERLEVEL9K_JENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_JENV_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_PLENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -a POWERLEVEL9K_PLENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_PLENV_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_PYENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -b POWERLEVEL9K_PYENV_SHOW_SYSTEM 1
	_p9k_declare -a POWERLEVEL9K_PYENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -a POWERLEVEL9K_GOENV_SOURCES -- shell local global
	_p9k_declare -b POWERLEVEL9K_GOENV_SHOW_SYSTEM 1
	_p9k_declare -b POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW 0
	_p9k_declare -b POWERLEVEL9K_ASDF_SHOW_SYSTEM 1
	_p9k_declare -a POWERLEVEL9K_ASDF_SOURCES -- shell local global
	local var
	for var in ${parameters[(I)POWERLEVEL9K_ASDF_*_PROMPT_ALWAYS_SHOW]}
	do
		_p9k_declare -b $var $_POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW
	done
	for var in ${parameters[(I)POWERLEVEL9K_ASDF_*_SHOW_SYSTEM]}
	do
		_p9k_declare -b $var $_POWERLEVEL9K_ASDF_SHOW_SYSTEM
	done
	for var in ${parameters[(I)POWERLEVEL9K_ASDF_*_SOURCES]}
	do
		_p9k_declare -a $var -- $_POWERLEVEL9K_ASDF_SOURCES
	done
	_p9k_declare -b POWERLEVEL9K_HASKELL_STACK_PROMPT_ALWAYS_SHOW 1
	_p9k_declare -a POWERLEVEL9K_HASKELL_STACK_SOURCES -- shell local
	_p9k_declare -b POWERLEVEL9K_RVM_SHOW_GEMSET 0
	_p9k_declare -b POWERLEVEL9K_RVM_SHOW_PREFIX 0
	_p9k_declare -b POWERLEVEL9K_CHRUBY_SHOW_VERSION 1
	_p9k_declare -b POWERLEVEL9K_CHRUBY_SHOW_ENGINE 1
	_p9k_declare -s POWERLEVEL9K_CHRUBY_SHOW_ENGINE_PATTERN
	if (( _POWERLEVEL9K_CHRUBY_SHOW_ENGINE ))
	then
		: ${_POWERLEVEL9K_CHRUBY_SHOW_ENGINE_PATTERN=*}
	fi
	_p9k_declare -b POWERLEVEL9K_STATUS_CROSS 0
	_p9k_declare -b POWERLEVEL9K_STATUS_OK 1
	_p9k_declare -b POWERLEVEL9K_STATUS_OK_PIPE 1
	_p9k_declare -b POWERLEVEL9K_STATUS_ERROR 1
	_p9k_declare -b POWERLEVEL9K_STATUS_ERROR_PIPE 1
	_p9k_declare -b POWERLEVEL9K_STATUS_ERROR_SIGNAL 1
	_p9k_declare -b POWERLEVEL9K_STATUS_SHOW_PIPESTATUS 1
	_p9k_declare -b POWERLEVEL9K_STATUS_HIDE_SIGNAME 0
	_p9k_declare -b POWERLEVEL9K_STATUS_VERBOSE_SIGNAME 1
	_p9k_declare -b POWERLEVEL9K_STATUS_EXTENDED_STATES 0
	_p9k_declare -b POWERLEVEL9K_STATUS_VERBOSE 1
	_p9k_declare -b POWERLEVEL9K_STATUS_OK_IN_NON_VERBOSE 0
	_p9k_declare -e POWERLEVEL9K_DATE_FORMAT "%D{%d.%m.%y}"
	_p9k_declare -s POWERLEVEL9K_VCS_ACTIONFORMAT_FOREGROUND 1
	_p9k_declare -b POWERLEVEL9K_SHOW_CHANGESET 0
	_p9k_declare -e POWERLEVEL9K_VCS_LOADING_TEXT loading
	_p9k_declare -a POWERLEVEL9K_VCS_GIT_HOOKS -- vcs-detect-changes git-untracked git-aheadbehind git-stash git-remotebranch git-tagname
	_p9k_declare -a POWERLEVEL9K_VCS_HG_HOOKS -- vcs-detect-changes
	_p9k_declare -a POWERLEVEL9K_VCS_SVN_HOOKS -- vcs-detect-changes svn-detect-changes
	_p9k_declare -F POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS 0.01
	(( POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS >= 0 )) || (( POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS = 0 ))
	_p9k_declare -a POWERLEVEL9K_VCS_BACKENDS -- git
	(( $+commands[git] )) || _POWERLEVEL9K_VCS_BACKENDS=(${_POWERLEVEL9K_VCS_BACKENDS:#git}) 
	_p9k_declare -b POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING 0
	_p9k_declare -i POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY -1
	_p9k_declare -i POWERLEVEL9K_VCS_STAGED_MAX_NUM 1
	_p9k_declare -i POWERLEVEL9K_VCS_UNSTAGED_MAX_NUM 1
	_p9k_declare -i POWERLEVEL9K_VCS_UNTRACKED_MAX_NUM 1
	_p9k_declare -i POWERLEVEL9K_VCS_CONFLICTED_MAX_NUM 1
	_p9k_declare -i POWERLEVEL9K_VCS_COMMITS_AHEAD_MAX_NUM -1
	_p9k_declare -i POWERLEVEL9K_VCS_COMMITS_BEHIND_MAX_NUM -1
	_p9k_declare -b POWERLEVEL9K_VCS_RECURSE_UNTRACKED_DIRS 0
	_p9k_declare -F POWERLEVEL9K_GITSTATUS_INIT_TIMEOUT_SEC 10
	_p9k_declare -b POWERLEVEL9K_DISABLE_GITSTATUS 0
	_p9k_declare -e POWERLEVEL9K_VI_INSERT_MODE_STRING "INSERT"
	_p9k_declare -e POWERLEVEL9K_VI_COMMAND_MODE_STRING "NORMAL"
	_p9k_declare -e POWERLEVEL9K_VI_VISUAL_MODE_STRING
	_p9k_declare -e POWERLEVEL9K_VI_OVERWRITE_MODE_STRING
	_p9k_declare -s POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV true
	_p9k_declare -b POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION 1
	_p9k_declare -e POWERLEVEL9K_VIRTUALENV_LEFT_DELIMITER "("
	_p9k_declare -e POWERLEVEL9K_VIRTUALENV_RIGHT_DELIMITER ")"
	_p9k_declare -a POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES -- virtualenv venv .venv env
	_POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES="${(j.|.)_POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES}" 
	_p9k_declare -b POWERLEVEL9K_NODEENV_SHOW_NODE_VERSION 1
	_p9k_declare -e POWERLEVEL9K_NODEENV_LEFT_DELIMITER "["
	_p9k_declare -e POWERLEVEL9K_NODEENV_RIGHT_DELIMITER "]"
	_p9k_declare -b POWERLEVEL9K_KUBECONTEXT_SHOW_DEFAULT_NAMESPACE 1
	_p9k_declare -a POWERLEVEL9K_KUBECONTEXT_SHORTEN --
	_p9k_declare -a POWERLEVEL9K_KUBECONTEXT_CLASSES --
	_p9k_declare -a POWERLEVEL9K_AWS_CLASSES --
	_p9k_declare -a POWERLEVEL9K_AZURE_CLASSES --
	_p9k_declare -a POWERLEVEL9K_TERRAFORM_CLASSES --
	_p9k_declare -b POWERLEVEL9K_TERRAFORM_SHOW_DEFAULT 0
	_p9k_declare -a POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES -- 'service_account:*' SERVICE_ACCOUNT
	_p9k_declare -b POWERLEVEL9K_JAVA_VERSION_FULL 1
	_p9k_declare -b POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE 0
	_p9k_declare -e POWERLEVEL9K_TIME_FORMAT "%D{%H:%M:%S}"
	_p9k_declare -b POWERLEVEL9K_TIME_UPDATE_ON_COMMAND 0
	_p9k_declare -b POWERLEVEL9K_EXPERIMENTAL_TIME_REALTIME 0
	_p9k_declare -b POWERLEVEL9K_NIX_SHELL_INFER_FROM_PATH 0
	typeset -g _p9k_nix_shell_cond='${IN_NIX_SHELL:#0}' 
	if (( _POWERLEVEL9K_NIX_SHELL_INFER_FROM_PATH ))
	then
		_p9k_nix_shell_cond+='${path[(r)/nix/store/*]}' 
	fi
	local -i i=1 
	while (( i <= $#_POWERLEVEL9K_LEFT_PROMPT_ELEMENTS ))
	do
		local segment=${${(U)_POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[i]}//İ/I} 
		local var=POWERLEVEL9K_${segment}_LEFT_DISABLED 
		(( $+parameters[$var] )) || var=POWERLEVEL9K_${segment}_DISABLED 
		if [[ ${(P)var} == true ]]
		then
			_POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[i,i]=() 
		else
			(( ++i ))
		fi
	done
	local -i i=1 
	while (( i <= $#_POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS ))
	do
		local segment=${${(U)_POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS[i]}//İ/I} 
		local var=POWERLEVEL9K_${segment}_RIGHT_DISABLED 
		(( $+parameters[$var] )) || var=POWERLEVEL9K_${segment}_DISABLED 
		if [[ ${(P)var} == true ]]
		then
			_POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS[i,i]=() 
		else
			(( ++i ))
		fi
	done
	local var
	for var in ${(@)${parameters[(I)POWERLEVEL9K_*]}/(#m)*/${(M)${parameters[_$MATCH]-$MATCH}:#$MATCH}}
	do
		case $parameters[$var] in
			((scalar|integer|float)*) typeset -g _$var=${(P)var} ;;
			(array*) eval 'typeset -ga '_$var'=("${'$var'[@]}")' ;;
		esac
	done
}
_p9k_init_prompt () {
	_p9k_t=($'\n' $'%{\n%}' '') 
	_p9k_prompt_overflow_bug && _p9k_t[2]=$'%{%G\n%}' 
	_p9k_init_lines
	_p9k_gap_pre='${${:-${_p9k__x::=0}${_p9k__y::=1024}${_p9k__p::=$_p9k__lprompt$_p9k__rprompt}' 
	repeat 10
	do
		_p9k_gap_pre+='${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}' 
		_p9k_gap_pre+='${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}' 
		_p9k_gap_pre+='${_p9k__x::=${_p9k__xy%;*}}' 
		_p9k_gap_pre+='${_p9k__y::=${_p9k__xy#*;}}' 
	done
	_p9k_gap_pre+='${_p9k__m::=$((_p9k__clm-_p9k__x-_p9k__ind-1))}' 
	_p9k_gap_pre+='}+}' 
	_p9k_prompt_prefix_left='${${_p9k__clm::=$COLUMNS}+}${${COLUMNS::=1024}+}' 
	_p9k_prompt_prefix_right='${_p9k__'$#_p9k_line_segments_left'-${${_p9k__clm::=$COLUMNS}+}${${COLUMNS::=1024}+}' 
	_p9k_prompt_suffix_left='${${COLUMNS::=$_p9k__clm}+}' 
	_p9k_prompt_suffix_right='${${COLUMNS::=$_p9k__clm}+}}' 
	if _p9k_segment_in_use vi_mode || _p9k_segment_in_use prompt_char
	then
		_p9k_prompt_prefix_left+='${${_p9k__keymap::=${KEYMAP:-$_p9k__keymap}}+}' 
	fi
	if {
			_p9k_segment_in_use vi_mode && (( $+_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING ))
		} || {
			_p9k_segment_in_use prompt_char && (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
		}
	then
		_p9k_prompt_prefix_left+='${${_p9k__zle_state::=${ZLE_STATE:-$_p9k__zle_state}}+}' 
	fi
	_p9k_prompt_prefix_left+='%b%k%f' 
	if [[ -n $_p9k_line_segments_right[-1] && $_p9k_line_never_empty_right[-1] == 0 && $ZLE_RPROMPT_INDENT == 0 ]] && _p9k_all_params_eq '_POWERLEVEL9K_*WHITESPACE_BETWEEN_RIGHT_SEGMENTS' ' ' && _p9k_all_params_eq '_POWERLEVEL9K_*RIGHT_RIGHT_WHITESPACE' ' ' && _p9k_all_params_eq '_POWERLEVEL9K_*RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL' '' && [[ $ZSH_VERSION != (5.7.<2->*|5.<8->*|<6->.*) ]]
	then
		_p9k_emulate_zero_rprompt_indent=1 
		_p9k_prompt_prefix_left+='${${:-${_p9k__real_zle_rprompt_indent:=$ZLE_RPROMPT_INDENT}${ZLE_RPROMPT_INDENT::=1}${_p9k__ind::=0}}+}' 
		_p9k_line_suffix_right[-1]='${_p9k__sss:+${_p9k__sss% }%E}}' 
	else
		_p9k_emulate_zero_rprompt_indent=0 
		_p9k_prompt_prefix_left+='${${_p9k__ind::=${${ZLE_RPROMPT_INDENT:-1}/#-*/0}}+}' 
	fi
	if (( _POWERLEVEL9K_TERM_SHELL_INTEGRATION ))
	then
		_p9k_prompt_prefix_left+=$'%{\e]133;A\a%}' 
		_p9k_prompt_suffix_left+=$'%{\e]133;B\a%}' 
		if [[ $TERM_PROGRAM == WarpTerminal ]]
		then
			_p9k_prompt_prefix_right=$'%{\e]133;P;k=r\a%}'$_p9k_prompt_prefix_right 
			_p9k_prompt_suffix_right+=$'%{\e]133;B\a%}' 
		fi
		if (( $+_z4h_iterm_cmd && _z4h_can_save_restore_screen == 1 ))
		then
			_p9k_prompt_prefix_left+=$'%{\ePtmux;\e\e]133;A\a\e\\%}' 
			_p9k_prompt_suffix_left+=$'%{\ePtmux;\e\e]133;B\a\e\\%}' 
			if [[ $TERM_PROGRAM == WarpTerminal ]]
			then
				_p9k_prompt_prefix_right=$'%{\ePtmux;\e\e]133;P;k=r\a\e\\%}'$_p9k_prompt_prefix_right 
				_p9k_prompt_suffix_right+=$'%{\ePtmux;\e\e]133;B\a\e\\%}' 
			fi
		fi
	fi
	if (( _POWERLEVEL9K_PROMPT_ADD_NEWLINE_COUNT > 0 ))
	then
		_p9k_t+=${(pl.$_POWERLEVEL9K_PROMPT_ADD_NEWLINE_COUNT..\n.)} 
	else
		_p9k_t+='' 
	fi
	_p9k_empty_line_idx=$#_p9k_t 
	if (( __p9k_ksh_arrays ))
	then
		_p9k_prompt_prefix_left+='${_p9k_t[${_p9k__empty_line_i:-'$#_p9k_t'}-1]}' 
	else
		_p9k_prompt_prefix_left+='${_p9k_t[${_p9k__empty_line_i:-'$#_p9k_t'}]}' 
	fi
	local -i num_lines=$#_p9k_line_segments_left 
	if (( $+terminfo[cuu1] ))
	then
		_p9k_escape $terminfo[cuu1]
		if (( __p9k_ksh_arrays ))
		then
			local scroll=$'${_p9k_t[${_p9k__ruler_i:-1}-1]:+\n'$_p9k__ret'}' 
		else
			local scroll=$'${_p9k_t[${_p9k__ruler_i:-1}]:+\n'$_p9k__ret'}' 
		fi
		if (( num_lines > 1 ))
		then
			local -i line_index= 
			for line_index in {1..$((num_lines-1))}
			do
				scroll='${_p9k__'$line_index-$'\n}'$scroll'${_p9k__'$line_index-$_p9k__ret'}' 
			done
		fi
		_p9k_prompt_prefix_left+='%{${_p9k__ipe-'$scroll'}%}' 
	fi
	_p9k_get_icon '' RULER_CHAR
	local ruler_char=$_p9k__ret 
	_p9k_prompt_length $ruler_char
	(( _p9k__ret == 1 && $#ruler_char == 1 )) || ruler_char=' ' 
	_p9k_color prompt_ruler BACKGROUND ""
	if [[ -z $_p9k__ret && $ruler_char == ' ' ]]
	then
		local ruler=$'\n' 
	else
		_p9k_background $_p9k__ret
		local ruler=%b$_p9k__ret 
		_p9k_color prompt_ruler FOREGROUND ""
		_p9k_foreground $_p9k__ret
		ruler+=$_p9k__ret 
		[[ $ruler_char == '.' ]] && local sep=','  || local sep='.' 
		ruler+='${(pl'$sep'${$((_p9k__clm-_p9k__ind))/#-*/0}'$sep$sep$ruler_char$sep')}%k%f' 
		if (( __p9k_ksh_arrays ))
		then
			ruler+='${_p9k_t[$((!_p9k__ind))]}' 
		else
			ruler+='${_p9k_t[$((1+!_p9k__ind))]}' 
		fi
	fi
	_p9k_t+=$ruler 
	_p9k_ruler_idx=$#_p9k_t 
	if (( __p9k_ksh_arrays ))
	then
		_p9k_prompt_prefix_left+='${(e)_p9k_t[${_p9k__ruler_i:-'$#_p9k_t'}-1]}' 
	else
		_p9k_prompt_prefix_left+='${(e)_p9k_t[${_p9k__ruler_i:-'$#_p9k_t'}]}' 
	fi
	(
		_p9k_segment_in_use time && (( _POWERLEVEL9K_TIME_UPDATE_ON_COMMAND ))
	)
	_p9k_reset_on_line_finish=$((!$?)) 
	_p9k_t+=$_p9k_gap_pre 
	_p9k_gap_pre='${(e)_p9k_t['$(($#_p9k_t - __p9k_ksh_arrays))']}' 
	_p9k_t+=$_p9k_prompt_prefix_left 
	_p9k_prompt_prefix_left='${(e)_p9k_t['$(($#_p9k_t - __p9k_ksh_arrays))']}' 
}
_p9k_init_ssh () {
	[[ -n $P9K_SSH && $_P9K_SSH_TTY == $TTY ]] && return
	typeset -gix P9K_SSH=0 
	typeset -gx _P9K_SSH_TTY=$TTY 
	if [[ -n $SSH_CLIENT || -n $SSH_TTY || -n $SSH_CONNECTION ]]
	then
		P9K_SSH=1 
		return 0
	fi
	(( $+commands[who] )) || return
	local ipv6='(([0-9a-fA-F]+:)|:){2,}[0-9a-fA-F]+' 
	local ipv4='([0-9]{1,3}\.){3}[0-9]+' 
	local hostname='([.][^. ]+){2}' 
	local w
	w="$(who -m 2>/dev/null)"  || w=${(@M)${(f)"$(who 2>/dev/null)"}:#*[[:space:]]${TTY#/dev/}[[:space:]]*} 
	[[ $w =~ "\(?($ipv4|$ipv6|$hostname)\)?\$" ]] && P9K_SSH=1 
}
_p9k_init_toolbox () {
	[[ -z $P9K_TOOLBOX_NAME ]] || return 0
	if [[ -f /run/.containerenv && -r /run/.containerenv ]]
	then
		local name=(${(Q)${${(@M)${(f)"$(</run/.containerenv)"}:#name=*}#name=}}) 
		[[ ${#name} -eq 1 && -n ${name[1]} ]] || return 0
		typeset -g P9K_TOOLBOX_NAME=${name[1]} 
	elif [[ -n $DISTROBOX_ENTER_PATH ]]
	then
		local name=${(%):-%m} 
		if [[ -n $name && $name == $NAME* ]]
		then
			typeset -g P9K_TOOLBOX_NAME=$name 
		fi
	fi
}
_p9k_init_vars () {
	typeset -gF _p9k__gcloud_last_fetch_ts
	typeset -g _p9k_gcloud_configuration
	typeset -g _p9k_gcloud_account
	typeset -g _p9k_gcloud_project_id
	typeset -g _p9k_gcloud_project_name
	typeset -gi _p9k_term_has_href
	typeset -gi _p9k_vcs_index
	typeset -gi _p9k_vcs_line_index
	typeset -g _p9k_vcs_side
	typeset -ga _p9k_taskwarrior_meta_files
	typeset -ga _p9k_taskwarrior_meta_non_files
	typeset -g _p9k_taskwarrior_meta_sig
	typeset -g _p9k_taskwarrior_data_dir
	typeset -g _p9k__taskwarrior_functional=1 
	typeset -ga _p9k_taskwarrior_data_files
	typeset -ga _p9k_taskwarrior_data_non_files
	typeset -g _p9k_taskwarrior_data_sig
	typeset -gA _p9k_taskwarrior_counters
	typeset -gF _p9k_taskwarrior_next_due
	typeset -ga _p9k_asdf_meta_files
	typeset -ga _p9k_asdf_meta_non_files
	typeset -g _p9k_asdf_meta_sig
	typeset -gA _p9k_asdf_plugins
	typeset -gA _p9k_asdf_file_info
	typeset -gA _p9k__asdf_dir2files
	typeset -gA _p9k_asdf_file2versions
	typeset -gA _p9k__read_word_cache
	typeset -gA _p9k__read_pyenv_like_version_file_cache
	typeset -ga _p9k__parent_dirs
	typeset -ga _p9k__parent_mtimes
	typeset -ga _p9k__parent_mtimes_i
	typeset -g _p9k__parent_mtimes_s
	typeset -g _p9k__cwd
	typeset -g _p9k__cwd_a
	typeset -gA _p9k__glob_cache
	typeset -gA _p9k__upsearch_cache
	typeset -g _p9k_timewarrior_dir
	typeset -gi _p9k_timewarrior_dir_mtime
	typeset -gi _p9k_timewarrior_file_mtime
	typeset -g _p9k_timewarrior_file_name
	typeset -gA _p9k__prompt_char_saved
	typeset -g _p9k__worker_pid
	typeset -g _p9k__worker_req_fd
	typeset -g _p9k__worker_resp_fd
	typeset -g _p9k__worker_shell_pid
	typeset -g _p9k__worker_file_prefix
	typeset -gA _p9k__worker_request_map
	typeset -ga _p9k__segment_cond_left
	typeset -ga _p9k__segment_cond_right
	typeset -ga _p9k__segment_val_left
	typeset -ga _p9k__segment_val_right
	typeset -ga _p9k_show_on_command
	typeset -g _p9k__last_buffer
	typeset -ga _p9k__last_commands
	typeset -gi _p9k__fully_initialized
	typeset -gi _p9k__must_restore_prompt
	typeset -gi _p9k__restore_prompt_fd
	typeset -gi _p9k__redraw_fd
	typeset -gi _p9k__can_hide_cursor=$(( $+terminfo[civis] && $+terminfo[cnorm] )) 
	if (( _p9k__can_hide_cursor ))
	then
		if [[ $terminfo[cnorm] == *$'\e[?25h'(|'\e'*) ]]
		then
			typeset -g _p9k__cnorm=$'\e[?25h' 
		else
			typeset -g _p9k__cnorm=$terminfo[cnorm] 
		fi
	fi
	typeset -gi _p9k__cursor_hidden
	typeset -gi _p9k__non_hermetic_expansion
	typeset -g _p9k__time
	typeset -g _p9k__date
	typeset -gA _p9k_dumped_instant_prompt_sigs
	typeset -g _p9k__instant_prompt_sig
	typeset -g _p9k__instant_prompt
	typeset -gi _p9k__state_dump_scheduled
	typeset -gi _p9k__state_dump_fd
	typeset -gi _p9k__prompt_idx
	typeset -gi _p9k_reset_on_line_finish
	typeset -gF _p9k__timer_start
	typeset -gi _p9k__status
	typeset -ga _p9k__pipestatus
	typeset -g _p9k__ret
	typeset -g _p9k__cache_key
	typeset -ga _p9k__cache_val
	typeset -g _p9k__cache_stat_meta
	typeset -g _p9k__cache_stat_fprint
	typeset -g _p9k__cache_fprint_key
	typeset -gA _p9k_cache
	typeset -gA _p9k__cache_ephemeral
	typeset -ga _p9k_t
	typeset -g _p9k__n
	typeset -gi _p9k__i
	typeset -g _p9k__bg
	typeset -ga _p9k_left_join
	typeset -ga _p9k_right_join
	typeset -g _p9k__public_ip
	typeset -g _p9k__todo_command
	typeset -g _p9k__todo_file
	typeset -g _p9k__git_dir
	typeset -gA _p9k_git_slow
	typeset -gA _p9k__gitstatus_last
	typeset -gF _p9k__gitstatus_start_time
	typeset -g _p9k__prompt
	typeset -g _p9k__rprompt
	typeset -g _p9k__lprompt
	typeset -g _p9k__prompt_side
	typeset -g _p9k__segment_name
	typeset -gi _p9k__segment_index
	typeset -gi _p9k__line_index
	typeset -g _p9k__refresh_reason
	typeset -gi _p9k__region_active
	typeset -ga _p9k_line_segments_left
	typeset -ga _p9k_line_segments_right
	typeset -ga _p9k_line_prefix_left
	typeset -ga _p9k_line_prefix_right
	typeset -ga _p9k_line_suffix_left
	typeset -ga _p9k_line_suffix_right
	typeset -ga _p9k_line_never_empty_right
	typeset -ga _p9k_line_gap_post
	typeset -g _p9k__xy
	typeset -g _p9k__clm
	typeset -g _p9k__p
	typeset -gi _p9k__x
	typeset -gi _p9k__y
	typeset -gi _p9k__m
	typeset -gi _p9k__d
	typeset -gi _p9k__h
	typeset -gi _p9k__ind
	typeset -g _p9k_gap_pre
	typeset -gi _p9k__ruler_i=3 
	typeset -gi _p9k_ruler_idx
	typeset -gi _p9k__empty_line_i=3 
	typeset -gi _p9k_empty_line_idx
	typeset -g _p9k_prompt_prefix_left
	typeset -g _p9k_prompt_prefix_right
	typeset -g _p9k_prompt_suffix_left
	typeset -g _p9k_prompt_suffix_right
	typeset -gi _p9k_emulate_zero_rprompt_indent
	typeset -gA _p9k_battery_states
	typeset -g _p9k_os
	typeset -g _p9k_os_icon
	typeset -g _p9k_color1
	typeset -g _p9k_color2
	typeset -g _p9k__s
	typeset -g _p9k__ss
	typeset -g _p9k__sss
	typeset -g _p9k__v
	typeset -g _p9k__c
	typeset -g _p9k__e
	typeset -g _p9k__w
	typeset -gi _p9k__dir_len
	typeset -gi _p9k_num_cpus
	typeset -g _p9k__keymap
	typeset -g _p9k__zle_state
	typeset -g _p9k_uname
	typeset -g _p9k_uname_o
	typeset -g _p9k_uname_m
	typeset -g _p9k_transient_prompt
	typeset -g _p9k__last_prompt_pwd
	typeset -gA _p9k_display_k
	typeset -ga _p9k__display_v
	typeset -gA _p9k__dotnet_stat_cache
	typeset -gA _p9k__dir_stat_cache
	typeset -gi _p9k__expanded
	typeset -gi _p9k__force_must_init
	typeset -g P9K_VISUAL_IDENTIFIER
	typeset -g P9K_CONTENT
	typeset -g P9K_GAP
	typeset -g P9K_PROMPT=regular 
}
_p9k_init_vcs () {
	if ! _p9k_segment_in_use vcs || (( ! $#_POWERLEVEL9K_VCS_BACKENDS ))
	then
		(( $+functions[gitstatus_stop_p9k_] )) && gitstatus_stop_p9k_ POWERLEVEL9K
		unset _p9k_preinit
		return
	fi
	_p9k_vcs_info_init
	if (( $+functions[_p9k_preinit] ))
	then
		if (( $+GITSTATUS_DAEMON_PID_POWERLEVEL9K ))
		then
			() {
				trap 'return 130' INT
				{
					gitstatus_start_p9k_ -t $_POWERLEVEL9K_GITSTATUS_INIT_TIMEOUT_SEC POWERLEVEL9K
				} always {
					trap ':' INT
				}
			}
		fi
		(( $+GITSTATUS_DAEMON_PID_POWERLEVEL9K )) || _p9k__instant_prompt_disabled=1 
		return 0
	fi
	(( _POWERLEVEL9K_DISABLE_GITSTATUS )) && return
	(( $_POWERLEVEL9K_VCS_BACKENDS[(I)git] )) || return
	local gitstatus_dir=${_POWERLEVEL9K_GITSTATUS_DIR:-${__p9k_root_dir}/gitstatus} 
	typeset -g _p9k_preinit="function _p9k_preinit() {
    (( $+commands[git] )) || { unfunction _p9k_preinit; return 1 }
    [[ \$ZSH_VERSION == ${(q)ZSH_VERSION} ]]                      || return
    [[ -r ${(q)gitstatus_dir}/gitstatus.plugin.zsh ]]             || return
    builtin source ${(q)gitstatus_dir}/gitstatus.plugin.zsh _p9k_ || return
    GITSTATUS_AUTO_INSTALL=${(q)GITSTATUS_AUTO_INSTALL}               GITSTATUS_DAEMON=${(q)GITSTATUS_DAEMON}                         GITSTATUS_CACHE_DIR=${(q)GITSTATUS_CACHE_DIR}                   GITSTATUS_NUM_THREADS=${(q)GITSTATUS_NUM_THREADS}               GITSTATUS_LOG_LEVEL=${(q)GITSTATUS_LOG_LEVEL}                   GITSTATUS_ENABLE_LOGGING=${(q)GITSTATUS_ENABLE_LOGGING}           gitstatus_start_p9k_                                              -s $_POWERLEVEL9K_VCS_STAGED_MAX_NUM                            -u $_POWERLEVEL9K_VCS_UNSTAGED_MAX_NUM                          -d $_POWERLEVEL9K_VCS_UNTRACKED_MAX_NUM                         -c $_POWERLEVEL9K_VCS_CONFLICTED_MAX_NUM                        -m $_POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY                      ${${_POWERLEVEL9K_VCS_RECURSE_UNTRACKED_DIRS:#0}:+-e}           -a POWERLEVEL9K
  }" 
	builtin source $gitstatus_dir/gitstatus.plugin.zsh _p9k_ || return
	() {
		trap 'return 130' INT
		{
			gitstatus_start_p9k_ -s $_POWERLEVEL9K_VCS_STAGED_MAX_NUM -u $_POWERLEVEL9K_VCS_UNSTAGED_MAX_NUM -d $_POWERLEVEL9K_VCS_UNTRACKED_MAX_NUM -c $_POWERLEVEL9K_VCS_CONFLICTED_MAX_NUM -m $_POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY -t $_POWERLEVEL9K_GITSTATUS_INIT_TIMEOUT_SEC ${${_POWERLEVEL9K_VCS_RECURSE_UNTRACKED_DIRS:#0}:+-e} POWERLEVEL9K
		} always {
			trap ':' INT
		}
	}
	(( $+GITSTATUS_DAEMON_PID_POWERLEVEL9K )) || _p9k__instant_prompt_disabled=1 
}
_p9k_iterm2_precmd () {
	builtin zle && return
	if (( _p9k__iterm_cmd )) && [[ -t 1 ]]
	then
		(( _p9k__iterm_cmd == 1 )) && builtin print -n '\e]133;C;\a'
		builtin printf '\e]133;D;%s\a' $1
	fi
	typeset -gi _p9k__iterm_cmd=1 
}
_p9k_iterm2_preexec () {
	if [[ -t 1 ]]
	then
		if (( ${+__p9k_use_osc133_c_cmdline} ))
		then
			() {
				emulate -L zsh -o extended_glob -o no_multibyte
				local MATCH MBEGIN MEND
				builtin printf '\e]133;C;cmdline_url=%s\a' "${1//(#m)[^a-zA-Z0-9"\/:_.-!'()~"]/%${(l:2::0:)$(([##16]#MATCH))}}"
			} "$1"
		else
			builtin print -n '\e]133;C;\a'
		fi
	fi
	typeset -gi _p9k__iterm_cmd=2 
}
_p9k_jenv_global_version () {
	_p9k_read_word ${JENV_ROOT:-$HOME/.jenv}/version || _p9k__ret=system 
}
_p9k_left_prompt_segment () {
	if ! _p9k_cache_get "$0" "$1" "$2" "$3" "$4" "$_p9k__segment_index"
	then
		_p9k_color $1 BACKGROUND $2
		local bg_color=$_p9k__ret 
		_p9k_background $bg_color
		local bg=$_p9k__ret 
		_p9k_color $1 FOREGROUND $3
		local fg_color=$_p9k__ret 
		_p9k_foreground $fg_color
		local fg=$_p9k__ret 
		local style=%b$bg$fg 
		local style_=${style//\}/\\\}} 
		_p9k_get_icon $1 LEFT_SEGMENT_SEPARATOR
		local sep=$_p9k__ret 
		_p9k_escape $_p9k__ret
		local sep_=$_p9k__ret 
		_p9k_get_icon $1 LEFT_SUBSEGMENT_SEPARATOR
		_p9k_escape $_p9k__ret
		local subsep_=$_p9k__ret 
		local icon_
		if [[ -n $4 ]]
		then
			_p9k_get_icon $1 $4
			_p9k_escape $_p9k__ret
			icon_=$_p9k__ret 
		fi
		_p9k_get_icon $1 LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL
		local start_sep=$_p9k__ret 
		[[ -n $start_sep ]] && start_sep="%b%k%F{$bg_color}$start_sep" 
		_p9k_get_icon $1 LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL $sep
		_p9k_escape $_p9k__ret
		local end_sep_=$_p9k__ret 
		_p9k_get_icon $1 WHITESPACE_BETWEEN_LEFT_SEGMENTS ' '
		local space=$_p9k__ret 
		_p9k_get_icon $1 LEFT_LEFT_WHITESPACE $space
		local left_space=$_p9k__ret 
		[[ $left_space == *%* ]] && left_space+=$style 
		_p9k_get_icon $1 LEFT_RIGHT_WHITESPACE $space
		_p9k_escape $_p9k__ret
		local right_space_=$_p9k__ret 
		[[ $right_space_ == *%* ]] && right_space_+=$style_ 
		local s='<_p9k__s>' ss='<_p9k__ss>' 
		local -i non_hermetic=0 
		local t=$(($#_p9k_t - __p9k_ksh_arrays)) 
		_p9k_t+=$start_sep$style$left_space 
		_p9k_t+=$style 
		if [[ -n $fg_color && $fg_color == $bg_color ]]
		then
			if [[ $fg_color == $_p9k_color1 ]]
			then
				_p9k_foreground $_p9k_color2
			else
				_p9k_foreground $_p9k_color1
			fi
			_p9k_t+=%b$bg$_p9k__ret$ss$style$left_space 
		else
			_p9k_t+=%b$bg$ss$style$left_space 
		fi
		_p9k_t+=%b$bg$s$style$left_space 
		local join="_p9k__i>=$_p9k_left_join[$_p9k__segment_index]" 
		_p9k_param $1 SELF_JOINED false
		if [[ $_p9k__ret == false ]]
		then
			if (( _p9k__segment_index > $_p9k_left_join[$_p9k__segment_index] ))
			then
				join+="&&_p9k__i<$_p9k__segment_index" 
			else
				join= 
			fi
		fi
		local p= 
		p+="\${_p9k__n::=}" 
		p+="\${\${\${_p9k__bg:-0}:#NONE}:-\${_p9k__n::=$((t+1))}}" 
		if [[ -n $join ]]
		then
			p+="\${_p9k__n:=\${\${\$(($join)):#0}:+$((t+2))}}" 
		fi
		if (( __p9k_sh_glob ))
		then
			p+="\${_p9k__n:=\${\${(M)\${:-x$bg_color}:#x\$_p9k__bg}:+$((t+3))}}" 
			p+="\${_p9k__n:=\${\${(M)\${:-x$bg_color}:#x\$${_p9k__bg:-0}}:+$((t+3))}}" 
		else
			p+="\${_p9k__n:=\${\${(M)\${:-x$bg_color}:#x(\$_p9k__bg|\${_p9k__bg:-0})}:+$((t+3))}}" 
		fi
		p+="\${_p9k__n:=$((t+4))}" 
		_p9k_param $1 VISUAL_IDENTIFIER_EXPANSION '${P9K_VISUAL_IDENTIFIER}'
		[[ $_p9k__ret == (|*[^\\])'$('* ]] && non_hermetic=1 
		local icon_exp_=${_p9k__ret:+\"$_p9k__ret\"} 
		_p9k_param $1 CONTENT_EXPANSION '${P9K_CONTENT}'
		[[ $_p9k__ret == (|*[^\\])'$('* ]] && non_hermetic=1 
		local content_exp_=${_p9k__ret:+\"$_p9k__ret\"} 
		if [[ ( $icon_exp_ != '"${P9K_VISUAL_IDENTIFIER}"' && $icon_exp_ == *'$'* ) || ( $content_exp_ != '"${P9K_CONTENT}"' && $content_exp_ == *'$'* ) ]]
		then
			p+="\${P9K_VISUAL_IDENTIFIER::=$icon_}" 
		fi
		local -i has_icon=-1 
		if [[ $icon_exp_ != '"${P9K_VISUAL_IDENTIFIER}"' && $icon_exp_ == *'$'* ]]
		then
			p+='${_p9k__v::='$icon_exp_$style_'}' 
		else
			[[ $icon_exp_ == '"${P9K_VISUAL_IDENTIFIER}"' ]] && _p9k__ret=$icon_  || _p9k__ret=$icon_exp_ 
			if [[ -n $_p9k__ret ]]
			then
				p+="\${_p9k__v::=$_p9k__ret" 
				[[ $_p9k__ret == *%* ]] && p+=$style_ 
				p+="}" 
				has_icon=1 
			else
				has_icon=0 
			fi
		fi
		p+='${_p9k__c::='$content_exp_'}${_p9k__c::=${_p9k__c//'$'\r''}}' 
		p+='${_p9k__e::=${${_p9k__'${_p9k__line_index}l${${1#prompt_}%%[A-Z0-9_]#}'+00}:-' 
		if (( has_icon == -1 ))
		then
			p+='${${(%):-$_p9k__c%1(l.1.0)}[-1]}${${(%):-$_p9k__v%1(l.1.0)}[-1]}}' 
		else
			p+='${${(%):-$_p9k__c%1(l.1.0)}[-1]}'$has_icon'}' 
		fi
		p+='}}+}' 
		p+='${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/'$ss'/$_p9k__ss}/'$s'/$_p9k__s}' 
		_p9k_param $1 ICON_BEFORE_CONTENT ''
		if [[ $_p9k__ret != false ]]
		then
			_p9k_param $1 PREFIX ''
			_p9k__ret=${(g::)_p9k__ret} 
			_p9k_escape $_p9k__ret
			p+=$_p9k__ret 
			[[ $_p9k__ret == *%* ]] && local -i need_style=1  || local -i need_style=0 
			if (( has_icon != 0 ))
			then
				_p9k_color $1 VISUAL_IDENTIFIER_COLOR $fg_color
				_p9k_foreground $_p9k__ret
				_p9k__ret=%b$bg$_p9k__ret 
				_p9k__ret=${_p9k__ret//\}/\\\}} 
				if [[ $_p9k__ret != $style_ ]]
				then
					p+=$_p9k__ret'${_p9k__v}'$style_ 
				else
					(( need_style )) && p+=$style_ 
					p+='${_p9k__v}' 
				fi
				_p9k_get_icon $1 LEFT_MIDDLE_WHITESPACE ' '
				if [[ -n $_p9k__ret ]]
				then
					_p9k_escape $_p9k__ret
					[[ _p9k__ret == *%* ]] && _p9k__ret+=$style_ 
					p+='${${(M)_p9k__e:#11}:+'$_p9k__ret'}' 
				fi
			elif (( need_style ))
			then
				p+=$style_ 
			fi
			p+='${_p9k__c}'$style_ 
		else
			_p9k_param $1 PREFIX ''
			_p9k__ret=${(g::)_p9k__ret} 
			_p9k_escape $_p9k__ret
			p+=$_p9k__ret 
			[[ $_p9k__ret == *%* ]] && p+=$style_ 
			p+='${_p9k__c}'$style_ 
			if (( has_icon != 0 ))
			then
				local -i need_style=0 
				_p9k_get_icon $1 LEFT_MIDDLE_WHITESPACE ' '
				if [[ -n $_p9k__ret ]]
				then
					_p9k_escape $_p9k__ret
					[[ $_p9k__ret == *%* ]] && need_style=1 
					p+='${${(M)_p9k__e:#11}:+'$_p9k__ret'}' 
				fi
				_p9k_color $1 VISUAL_IDENTIFIER_COLOR $fg_color
				_p9k_foreground $_p9k__ret
				_p9k__ret=%b$bg$_p9k__ret 
				_p9k__ret=${_p9k__ret//\}/\\\}} 
				[[ $_p9k__ret != $style_ || $need_style == 1 ]] && p+=$_p9k__ret 
				p+='$_p9k__v' 
			fi
		fi
		_p9k_param $1 SUFFIX ''
		_p9k__ret=${(g::)_p9k__ret} 
		_p9k_escape $_p9k__ret
		p+=$_p9k__ret 
		[[ $_p9k__ret == *%* && -n $right_space_ ]] && p+=$style_ 
		p+=$right_space_ 
		p+='${${:-' 
		p+="\${_p9k__s::=%F{$bg_color\}$sep_}\${_p9k__ss::=$subsep_}\${_p9k__sss::=%F{$bg_color\}$end_sep_}" 
		p+="\${_p9k__i::=$_p9k__segment_index}\${_p9k__bg::=$bg_color}" 
		p+='}+}' 
		p+='}' 
		_p9k_param $1 SHOW_ON_UPGLOB ''
		_p9k_cache_set "$p" $non_hermetic $_p9k__ret
	fi
	if [[ -n $_p9k__cache_val[3] ]]
	then
		_p9k__has_upglob=1 
		_p9k_upglob $_p9k__cache_val[3] && return
	fi
	_p9k__non_hermetic_expansion=$_p9k__cache_val[2] 
	(( $5 )) && _p9k__ret=\"$7\"  || _p9k_escape $7
	if [[ -z $6 ]]
	then
		_p9k__prompt+="\${\${:-\${P9K_CONTENT::=$_p9k__ret}$_p9k__cache_val[1]" 
	else
		_p9k__prompt+="\${\${:-\"$6\"}:+\${\${:-\${P9K_CONTENT::=$_p9k__ret}$_p9k__cache_val[1]}" 
	fi
}
_p9k_luaenv_global_version () {
	_p9k_read_word ${LUAENV_ROOT:-$HOME/.luaenv}/version || _p9k__ret=system 
}
_p9k_maybe_ignore_git_repo () {
	if [[ $VCS_STATUS_RESULT == ok-* && $VCS_STATUS_WORKDIR == $~_POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN ]]
	then
		VCS_STATUS_RESULT=norepo${VCS_STATUS_RESULT#ok} 
	fi
}
_p9k_must_init () {
	(( _POWERLEVEL9K_DISABLE_HOT_RELOAD && !_p9k__force_must_init )) && return 1
	_p9k__force_must_init=0 
	local IFS sig
	if [[ -n $_p9k__param_sig ]]
	then
		IFS=$'\2' sig="${(e)_p9k__param_pat}" 
		[[ $sig == $_p9k__param_sig ]] && return 1
		_p9k_deinit
	fi
	_p9k__param_pat=${(q)P9K_VERSION}$'\1'${(q)ZSH_VERSION}$'\1'${(q)ZSH_PATCHLEVEL}$'\1' 
	_p9k__param_pat+=$__p9k_force_term_shell_integration$'\1'${(q)TERM_PROGRAM}$'\1' 
	_p9k__param_pat+=$'${#parameters[(I)POWERLEVEL9K_*]}\1${(%):-%n%#}\1$GITSTATUS_LOG_LEVEL\1' 
	_p9k__param_pat+=$'$GITSTATUS_ENABLE_LOGGING\1$GITSTATUS_DAEMON\1$GITSTATUS_NUM_THREADS\1' 
	_p9k__param_pat+=$'$GITSTATUS_CACHE_DIR\1$GITSTATUS_AUTO_INSTALL\1${ZLE_RPROMPT_INDENT:-1}\1' 
	_p9k__param_pat+=$'$__p9k_sh_glob\1$__p9k_ksh_arrays\1$ITERM_SHELL_INTEGRATION_INSTALLED\1' 
	_p9k__param_pat+=$'${PROMPT_EOL_MARK-%B%S%#%s%b}\1$+commands[locale]\1$langinfo[CODESET]\1' 
	_p9k__param_pat+=$'${(M)VTE_VERSION:#(<1-4602>|4801)}\1$DEFAULT_USER\1$P9K_SSH\1$+commands[uname]\1' 
	_p9k__param_pat+=$'$__p9k_root_dir\1$functions[p10k-on-init]\1$functions[p10k-on-pre-prompt]\1' 
	_p9k__param_pat+=$'$functions[p10k-on-post-widget]\1$functions[p10k-on-post-prompt]\1' 
	_p9k__param_pat+=$'$+commands[git]\1$terminfo[colors]\1${+_z4h_iterm_cmd}\1' 
	_p9k__param_pat+=$'$_z4h_can_save_restore_screen' 
	local MATCH
	IFS=$'\1' _p9k__param_pat+="${(@)${(@o)parameters[(I)POWERLEVEL9K_*]}:/(#m)*/\${${(q)MATCH}-$IFS\}}" 
	IFS=$'\2' _p9k__param_sig="${(e)_p9k__param_pat}" 
}
_p9k_nodeenv_version_transform () {
	local dir=${NODENV_ROOT:-$HOME/.nodenv}/versions 
	[[ -z $1 || $1 == system ]] && _p9k__ret=$1  && return
	[[ -d $dir/$1 ]] && _p9k__ret=$1  && return
	[[ -d $dir/${1/v} ]] && _p9k__ret=${1/v}  && return
	[[ -d $dir/${1#node-} ]] && _p9k__ret=${1#node-}  && return
	[[ -d $dir/${1#node-v} ]] && _p9k__ret=${1#node-v}  && return
	return 1
}
_p9k_nodenv_global_version () {
	_p9k_read_word ${NODENV_ROOT:-$HOME/.nodenv}/version || _p9k__ret=system 
}
_p9k_nvm_ls_current () {
	local node_path=${commands[node]:A} 
	[[ -n $node_path ]] || return
	local nvm_dir=${NVM_DIR:A} 
	if [[ -n $nvm_dir && $node_path == $nvm_dir/versions/io.js/* ]]
	then
		_p9k_cached_cmd 0 '' iojs --version || return
		_p9k__ret=iojs-v${_p9k__ret#v} 
	elif [[ -n $nvm_dir && $node_path == $nvm_dir/* ]]
	then
		_p9k_cached_cmd 0 '' node --version || return
		_p9k__ret=v${_p9k__ret#v} 
	else
		_p9k__ret=system 
	fi
}
_p9k_nvm_ls_default () {
	local v=default 
	local -a seen=($v) 
	while [[ -r $NVM_DIR/alias/$v ]]
	do
		local target= 
		IFS='' read -r target < $NVM_DIR/alias/$v
		target=${target%$'\r'} 
		[[ -z $target ]] && break
		(( $seen[(I)$target] )) && return
		seen+=$target 
		v=$target 
	done
	case $v in
		(default | N/A) return 1 ;;
		(system | v) _p9k__ret=system 
			return 0 ;;
		(iojs-[0-9]*) v=iojs-v${v#iojs-}  ;;
		([0-9]*) v=v$v  ;;
	esac
	if [[ $v == v*.*.* ]]
	then
		if [[ -x $NVM_DIR/versions/node/$v/bin/node || -x $NVM_DIR/$v/bin/node ]]
		then
			_p9k__ret=$v 
			return 0
		elif [[ -x $NVM_DIR/versions/io.js/$v/bin/node ]]
		then
			_p9k__ret=iojs-$v 
			return 0
		else
			return 1
		fi
	fi
	local -a dirs=() 
	case $v in
		(node | node- | stable) dirs=($NVM_DIR/versions/node $NVM_DIR) 
			v='(v[1-9]*|v0.*[02468].*)'  ;;
		(unstable) dirs=($NVM_DIR/versions/node $NVM_DIR) 
			v='v0.*[13579].*'  ;;
		(iojs*) dirs=($NVM_DIR/versions/io.js) 
			v=v${${${v#iojs}#-}#v}'*'  ;;
		(*) dirs=($NVM_DIR/versions/node $NVM_DIR $NVM_DIR/versions/io.js) 
			v=v${v#v}'*'  ;;
	esac
	local -a matches=(${^dirs}/${~v}(/N)) 
	(( $#matches )) || return
	local max path
	for path in ${(Oa)matches}
	do
		[[ ${path:t} == (#b)v(*).(*).(*) ]] || continue
		v=${(j::)${(@l:6::0:)match}} 
		[[ $v > $max ]] || continue
		max=$v 
		_p9k__ret=${path:t} 
		[[ ${path:h:t} != io.js ]] || _p9k__ret=iojs-$_p9k__ret 
	done
	[[ -n $max ]]
}
_p9k_on_expand () {
	(( _p9k__expanded && ! ${+__p9k_instant_prompt_active} )) && [[ "${langinfo[CODESET]}" == (utf|UTF)(-|)8 ]] && return
	eval "$__p9k_intro_no_locale"
	if [[ $langinfo[CODESET] != (utf|UTF)(-|)8 ]]
	then
		_p9k_restore_special_params
		if [[ $langinfo[CODESET] != (utf|UTF)(-|)8 ]] && _p9k_init_locale
		then
			if [[ -n $LC_ALL ]]
			then
				_p9k__real_lc_all=$LC_ALL 
				LC_ALL=$__p9k_locale 
			else
				_p9k__real_lc_ctype=$LC_CTYPE 
				LC_CTYPE=$__p9k_locale 
			fi
		fi
	fi
	(( _p9k__expanded && ! $+__p9k_instant_prompt_active )) && return
	eval "$__p9k_intro_locale"
	if (( ! _p9k__expanded ))
	then
		if _p9k_should_dump
		then
			sysopen -o cloexec -ru _p9k__state_dump_fd /dev/null
			zle -F $_p9k__state_dump_fd _p9k_do_dump
		fi
		if [[ -z $P9K_TTY || ( $P9K_TTY == old && -n ${_P9K_TTY:#$TTY} ) ]]
		then
			typeset -gx P9K_TTY=old 
			if (( _POWERLEVEL9K_NEW_TTY_MAX_AGE_SECONDS < 0 ))
			then
				P9K_TTY=new 
			else
				local -a stat
				if zstat -A stat +ctime -- $TTY 2> /dev/null && (( EPOCHREALTIME - stat[1] < _POWERLEVEL9K_NEW_TTY_MAX_AGE_SECONDS ))
				then
					P9K_TTY=new 
				fi
			fi
		fi
		typeset -gx _P9K_TTY=$TTY 
		__p9k_reset_state=1 
		if (( _POWERLEVEL9K_PROMPT_ADD_NEWLINE ))
		then
			if [[ $P9K_TTY == new ]]
			then
				_p9k__empty_line_i=3 
				_p9k__display_v[2]=hide 
			elif [[ -z $_p9k_transient_prompt && $+functions[p10k-on-post-prompt] == 0 ]]
			then
				_p9k__empty_line_i=3 
				_p9k__display_v[2]=print 
			else
				unset _p9k__empty_line_i
				_p9k__display_v[2]=show 
			fi
		fi
		if (( _POWERLEVEL9K_SHOW_RULER ))
		then
			if [[ $P9K_TTY == new ]]
			then
				_p9k__ruler_i=3 
				_p9k__display_v[4]=hide 
			elif [[ -z $_p9k_transient_prompt && $+functions[p10k-on-post-prompt] == 0 ]]
			then
				_p9k__ruler_i=3 
				_p9k__display_v[4]=print 
			else
				unset _p9k__ruler_i
				_p9k__display_v[4]=show 
			fi
		fi
		(( _p9k__fully_initialized )) || _p9k_wrap_widgets
	fi
	if (( $+__p9k_instant_prompt_active ))
	then
		_p9k_clear_instant_prompt
		unset __p9k_instant_prompt_active
	fi
	if (( ! _p9k__expanded ))
	then
		_p9k__expanded=1 
		(( _p9k__fully_initialized || ! $+functions[p10k-on-init] )) || p10k-on-init
		local pat idx var
		for pat idx var in $_p9k_show_on_command
		do
			_p9k_display_segment $idx $var hide
		done
		(( $+functions[p10k-on-pre-prompt] )) && p10k-on-pre-prompt
		if zle
		then
			local -a P9K_COMMANDS=($_p9k__last_commands) 
			local pat idx var
			for pat idx var in $_p9k_show_on_command
			do
				if (( $P9K_COMMANDS[(I)$pat] ))
				then
					_p9k_display_segment $idx $var show
				else
					_p9k_display_segment $idx $var hide
				fi
			done
			if (( $+functions[p10k-on-post-widget] ))
			then
				local -h WIDGET
				unset WIDGET
				p10k-on-post-widget
			fi
		else
			if [[ $_p9k__display_v[2] == print && -n $_p9k_t[_p9k_empty_line_idx] ]]
			then
				print -rnP -- '%b%k%f%E'$_p9k_t[_p9k_empty_line_idx]
			fi
			if [[ $_p9k__display_v[4] == print ]]
			then
				() {
					local ruler=$_p9k_t[_p9k_ruler_idx] 
					local -i _p9k__clm=COLUMNS _p9k__ind=${ZLE_RPROMPT_INDENT:-1} 
					(( __p9k_ksh_arrays )) && setopt ksh_arrays
					(( __p9k_sh_glob )) && setopt sh_glob
					setopt prompt_subst
					print -rnP -- '%b%k%f%E'$ruler
				}
			fi
		fi
		__p9k_reset_state=0 
		_p9k__fully_initialized=1 
	fi
}
_p9k_on_widget_deactivate-region () {
	_p9k_check_visual_mode
}
_p9k_on_widget_overwrite-mode () {
	_p9k_check_visual_mode
	__p9k_reset_state=2 
}
_p9k_on_widget_send-break () {
	_p9k_on_widget_zle-line-finish int
}
_p9k_on_widget_vi-replace () {
	_p9k_check_visual_mode
	__p9k_reset_state=2 
}
_p9k_on_widget_visual-line-mode () {
	_p9k_check_visual_mode
}
_p9k_on_widget_visual-mode () {
	_p9k_check_visual_mode
}
_p9k_on_widget_zle-keymap-select () {
	_p9k_check_visual_mode
	__p9k_reset_state=2 
}
_p9k_on_widget_zle-line-finish () {
	(( $+_p9k__line_finished )) && return
	local P9K_PROMPT=transient 
	_p9k__line_finished= 
	(( _p9k_reset_on_line_finish )) && __p9k_reset_state=2 
	(( $+functions[p10k-on-post-prompt] )) && p10k-on-post-prompt
	local -i optimized
	if [[ -n $_p9k_transient_prompt ]]
	then
		if [[ $_POWERLEVEL9K_TRANSIENT_PROMPT == always || $_p9k__cwd == $_p9k__last_prompt_pwd ]]
		then
			optimized=1 
			__p9k_reset_state=2 
		else
			_p9k__last_prompt_pwd=$_p9k__cwd 
		fi
	fi
	if [[ $1 == int ]]
	then
		_p9k__must_restore_prompt=1 
		if (( !_p9k__restore_prompt_fd ))
		then
			sysopen -o cloexec -ru _p9k__restore_prompt_fd /dev/null
			zle -F $_p9k__restore_prompt_fd _p9k_restore_prompt
		fi
	fi
	if (( __p9k_reset_state == 2 ))
	then
		if (( optimized ))
		then
			RPROMPT= PROMPT=$_p9k_transient_prompt _p9k_reset_prompt
		else
			_p9k_reset_prompt
		fi
	fi
	_p9k__line_finished='%{%}' 
}
_p9k_on_widget_zle-line-init () {
	(( _p9k__cursor_hidden )) || return 0
	_p9k__cursor_hidden=0 
	print -rn -- $_p9k__cnorm
}
_p9k_param () {
	local key="_p9k_param ${(pj:\0:)*}" 
	_p9k__ret=$_p9k_cache[$key] 
	if [[ -n $_p9k__ret ]]
	then
		_p9k__ret[-1,-1]='' 
	else
		if [[ ${1//-/_} == (#b)prompt_([a-z0-9_]#)(*) ]]
		then
			local var=_POWERLEVEL9K_${${(U)match[1]}//İ/I}$match[2]_$2 
			if (( $+parameters[$var] ))
			then
				_p9k__ret=${(P)var} 
			else
				var=_POWERLEVEL9K_${${(U)match[1]%_}//İ/I}_$2 
				if (( $+parameters[$var] ))
				then
					_p9k__ret=${(P)var} 
				else
					var=_POWERLEVEL9K_$2 
					if (( $+parameters[$var] ))
					then
						_p9k__ret=${(P)var} 
					else
						_p9k__ret=$3 
					fi
				fi
			fi
		else
			local var=_POWERLEVEL9K_$2 
			if (( $+parameters[$var] ))
			then
				_p9k__ret=${(P)var} 
			else
				_p9k__ret=$3 
			fi
		fi
		_p9k_cache[$key]=${_p9k__ret}. 
	fi
}
_p9k_parse_aws_config () {
	local cfg=$1 
	typeset -ga reply=() 
	[[ -f $cfg && -r $cfg ]] || return
	local -a lines
	lines=(${(f)"$(<$cfg)"})  || return
	local line profile
	local -a match mbegin mend
	for line in $lines
	do
		if [[ $line == [[:space:]]#'[default]'[[:space:]]#(|'#'*) ]]
		then
			profile=default 
		elif [[ $line == (#b)'[profile'[[:space:]]##([^[:space:]]|[^[:space:]]*[^[:space:]])[[:space:]]#']'[[:space:]]#(|'#'*) ]]
		then
			profile=${(Q)match[1]} 
		elif [[ $line == (#b)[[:space:]]#region[[:space:]]#=[[:space:]]#([^[:space:]]|[^[:space:]]*[^[:space:]])[[:space:]]# ]]
		then
			if [[ -n $profile ]]
			then
				reply+=$#profile:$profile:$match[1] 
				profile= 
			fi
		fi
	done
}
_p9k_parse_buffer () {
	[[ ${2:-0} == <-> ]] || return 2
	local rcquotes
	[[ -o rcquotes ]] && rcquotes=rcquotes 
	eval "$__p9k_intro"
	setopt no_nomatch $rcquotes
	typeset -ga P9K_COMMANDS=() 
	local -r id='(<->|[[:alpha:]_][[:IDENT:]]#)' 
	local -r var="\$$id|\${$id}|\"\$$id\"|\"\${$id}\"" 
	local -i e ic c=${2:-'1 << 62'} 
	local skip n s r state token cmd prev
	local -a aln alp alf v
	if [[ -o interactive_comments ]]
	then
		ic=1 
		local tokens=(${(Z+C+)1}) 
	else
		local tokens=(${(z)1}) 
	fi
	{
		while (( $#tokens ))
		do
			(( e = $#state ))
			while (( $#tokens == alp[-1] ))
			do
				aln[-1]=() 
				alp[-1]=() 
				if (( $#tokens == alf[-1] ))
				then
					alf[-1]=() 
					(( e = 0 ))
				fi
			done
			while (( c-- > 0 )) || return
			do
				token=$tokens[1] 
				tokens[1]=() 
				if (( $+galiases[$token] ))
				then
					(( $aln[(eI)p$token] )) && break
					s=$galiases[$token] 
					n=p$token 
				elif (( e ))
				then
					break
				elif (( $+aliases[$token] ))
				then
					(( $aln[(eI)p$token] )) && break
					s=$aliases[$token] 
					n=p$token 
				elif [[ $token == ?*.?* ]] && (( $+saliases[${token##*.}] ))
				then
					r=${token##*.} 
					(( $aln[(eI)s$r] )) && break
					s=${saliases[$r]%% #} 
					n=s$r 
				else
					break
				fi
				aln+=$n 
				alp+=$#tokens 
				[[ $s == *' ' ]] && alf+=$#tokens 
				(( ic )) && tokens[1,0]=(${(Z+C+)s})  || tokens[1,0]=(${(z)s}) 
			done
			case $token in
				('<<'(|-)) state=h 
					continue ;;
				(*('`'|['<>=$']'(')*) if [[ $token == ('`'[^'`']##'`'|'"`'[^'`']##'`"'|'$('[^')']##')'|'"$('[^')']##')"'|['<>=']'('[^')']##')') ]]
					then
						s=${${token##('"'|)(['$<>']|)?}%%?('"'|)} 
						(( ic )) && tokens+=(';' ${(Z+C+)s})  || tokens+=(';' ${(z)s}) 
					fi ;;
			esac
			case $state in
				(*r) state[-1]= 
					continue ;;
				(a) if [[ $token == $skip ]]
					then
						if [[ $token == '{' ]]
						then
							P9K_COMMANDS+=$cmd 
							cmd= 
							state= 
						else
							skip='{' 
						fi
						continue
					else
						state=t 
					fi ;&
				(t | p*) if (( $+__p9k_pb_term[$token] ))
					then
						if [[ $token == '()' ]]
						then
							state= 
						else
							P9K_COMMANDS+=$cmd 
							if [[ $token == '}' ]]
							then
								state=a 
								skip=always 
							else
								skip=$__p9k_pb_term_skip[$token] 
								state=${skip:+s} 
							fi
						fi
						cmd= 
						continue
					elif [[ $state == t ]]
					then
						continue
					elif [[ $state == *x ]]
					then
						if (( $+__p9k_pb_redirect[$token] ))
						then
							prev= 
							state[-1]=r 
							continue
						else
							state[-1]= 
						fi
					fi ;;
				(s) if [[ $token == $~skip ]]
					then
						state= 
					fi
					continue ;;
				(h) while (( $#tokens ))
					do
						(( e = ${tokens[(i)${(Q)token}]} ))
						if [[ $tokens[e-1] == ';' && $tokens[e+1] == ';' ]]
						then
							tokens[1,e]=() 
							break
						else
							tokens[1,e]=() 
						fi
					done
					while (( $#alp && alp[-1] >= $#tokens ))
					do
						aln[-1]=() 
						alp[-1]=() 
					done
					state=t 
					continue ;;
			esac
			if (( $+__p9k_pb_redirect[${token#<0-255>}] ))
			then
				state+=r 
				continue
			fi
			if [[ $token == *'$'* ]]
			then
				if [[ $token == $~var ]]
				then
					n=${${token##[^[:IDENT:]]}%%[^[:IDENT:]]} 
					[[ $token == *'"' ]] && v=("${(P)n}")  || v=(${(P)n}) 
					tokens[1,0]=(${(@qq)v}) 
					continue
				fi
			fi
			case $state in
				('') if (( $+__p9k_pb_cmd_skip[$token] ))
					then
						skip=$__p9k_pb_cmd_skip[$token] 
						[[ $token == '}' ]] && state=a  || state=${skip:+s} 
						continue
					fi
					if [[ $token == *=* ]]
					then
						v=${(S)token/#(<->|([[:alpha:]_][[:IDENT:]]#(|'['*[^\\](\\\\)#']')))(|'+')=} 
						if (( $#v < $#token ))
						then
							if [[ $v == '(' ]]
							then
								state=s 
								skip='\)' 
							fi
							continue
						fi
					fi
					: ${token::=${(Q)${~token}}} ;;
				(p2) if [[ -n $prev ]]
					then
						prev= 
					else
						: ${token::=${(Q)${~token}}}
						if [[ $token == '{'$~id'}' ]]
						then
							state=p2x 
							prev=$token 
						else
							state=p 
						fi
						continue
					fi ;&
				(p) if [[ -n $prev ]]
					then
						token=$prev 
						prev= 
					else
						: ${token::=${(Q)${~token}}}
						case $token in
							('{'$~id'}') prev=$token 
								state=px 
								continue ;;
							([^-]*)  ;;
							(--) state=p1 
								continue ;;
							($~skip) state=p2 
								continue ;;
							(*) continue ;;
						esac
					fi ;;
				(p1) if [[ -n $prev ]]
					then
						token=$prev 
						prev= 
					else
						: ${token::=${(Q)${~token}}}
						if [[ $token == '{'$~id'}' ]]
						then
							state=p1x 
							prev=$token 
							continue
						fi
					fi ;;
			esac
			if (( $+__p9k_pb_precommand[$token] ))
			then
				prev= 
				state=p 
				skip=$__p9k_pb_precommand[$token] 
				cmd+=$token$'\0' 
			else
				state=t 
				[[ $token == ('(('*'))'|'`'*'`'|'$'*|['<>=']'('*')'|*$'\0'*) ]] || cmd+=$token$'\0' 
			fi
		done
	} always {
		[[ $state == (px|p1x) ]] && cmd+=$prev 
		P9K_COMMANDS+=$cmd 
		P9K_COMMANDS=(${(u)P9K_COMMANDS%$'\0'}) 
	}
}
_p9k_parse_virtualenv_cfg () {
	typeset -ga reply=(0) 
	[[ -f $1 && -r $1 ]] || return
	local cfg
	cfg=$(<$1)  || return
	local -a match mbegin mend
	[[ $'\n'$cfg$'\n' == (#b)*$'\n'prompt[$' \t']#=([^$'\n']#)$'\n'* ]] || return
	local res=${${match[1]##[$' \t']#}%%[$' \t']#} 
	if [[ $res == (\"*\"|\'*\') ]]
	then
		res=${(Vg:e:)${res[2,-2]}} 
	fi
	reply=(1 "$res") 
}
_p9k_phpenv_global_version () {
	_p9k_read_word ${PHPENV_ROOT:-$HOME/.phpenv}/version || _p9k__ret=system 
}
_p9k_plenv_global_version () {
	_p9k_read_word ${PLENV_ROOT:-$HOME/.plenv}/version || _p9k__ret=system 
}
_p9k_precmd () {
	__p9k_new_status=$? 
	__p9k_new_pipestatus=($pipestatus) 
	trap ":" INT
	[[ -o ksh_arrays ]] && __p9k_ksh_arrays=1  || __p9k_ksh_arrays=0 
	[[ -o sh_glob ]] && __p9k_sh_glob=1  || __p9k_sh_glob=0 
	_p9k_restore_special_params
	_p9k_precmd_impl
	[[ ${+__p9k_instant_prompt_active} == 0 || -o no_prompt_cr ]] || __p9k_instant_prompt_active=2 
	setopt no_local_options no_prompt_bang prompt_percent prompt_subst prompt_cr prompt_sp
	typeset -g __p9k_trapint='_p9k_trapint; return 130' 
	trap "$__p9k_trapint" INT
	: ${(%):-%b%k%s%u}
}
_p9k_precmd_first () {
	eval "$__p9k_intro"
	if [[ -n $KITTY_SHELL_INTEGRATION && KITTY_SHELL_INTEGRATION[(wIe)no-prompt-mark] -eq 0 ]]
	then
		KITTY_SHELL_INTEGRATION+=' no-prompt-mark' 
		(( $+__p9k_force_term_shell_integration )) || typeset -gri __p9k_force_term_shell_integration=1 
		(( $+__p9k_use_osc133_c_cmdline         )) || typeset -gri __p9k_use_osc133_c_cmdline=1 
	elif [[ $TERM_PROGRAM == WarpTerminal ]]
	then
		(( $+__p9k_force_term_shell_integration )) || typeset -gri __p9k_force_term_shell_integration=1 
	fi
	typeset -ga precmd_functions=(${precmd_functions:#_p9k_precmd_first}) 
}
_p9k_precmd_impl () {
	eval "$__p9k_intro"
	(( __p9k_enabled )) || return
	if ! zle || [[ -z $_p9k__param_sig ]]
	then
		if zle
		then
			__p9k_new_status=0 
			__p9k_new_pipestatus=(0) 
		else
			_p9k__must_restore_prompt=0 
		fi
		if _p9k_must_init
		then
			local -i instant_prompt_disabled
			if (( !__p9k_configured ))
			then
				__p9k_configured=1 
				if [[ -z "${parameters[(I)POWERLEVEL9K_*~POWERLEVEL9K_(MODE|CONFIG_FILE|GITSTATUS_DIR)]}" ]]
				then
					_p9k_can_configure -q
					local -i ret=$? 
					if (( ret == 2 && $+__p9k_instant_prompt_active ))
					then
						_p9k_clear_instant_prompt
						unset __p9k_instant_prompt_active
						_p9k_delete_instant_prompt
						zf_rm -f -- $__p9k_dump_file{,.zwc} 2> /dev/null
						() {
							local key
							while true
							do
								[[ -t 2 ]]
								read -t0 -k key || break
							done 2> /dev/null
						}
						_p9k_can_configure -q
						ret=$? 
					fi
					if (( ret == 0 ))
					then
						if (( $+commands[git] ))
						then
							(
								local -i pid
								{
									{
										/bin/sh "$__p9k_root_dir"/gitstatus/install < /dev/null &> /dev/null &
									} && pid=$! 
									(
										builtin source "$__p9k_root_dir"/internal/wizard.zsh
									)
								} always {
									if (( pid ))
									then
										kill -- $pid 2> /dev/null
										wait -- $pid 2> /dev/null
									fi
								}
							)
						else
							(
								builtin source "$__p9k_root_dir"/internal/wizard.zsh
							)
						fi
						if (( $? ))
						then
							instant_prompt_disabled=1 
						else
							builtin source "$__p9k_cfg_path"
							_p9k__force_must_init=1 
							_p9k_must_init
						fi
					fi
				fi
			fi
			typeset -gi _p9k__instant_prompt_disabled=instant_prompt_disabled 
			_p9k_init
		fi
		if (( _p9k__timer_start ))
		then
			typeset -gF P9K_COMMAND_DURATION_SECONDS=$((EPOCHREALTIME - _p9k__timer_start)) 
		else
			unset P9K_COMMAND_DURATION_SECONDS
		fi
		_p9k_save_status
		if [[ $_p9k__preexec_cmd == [[:space:]]#(clear([[:space:]]##-(|x)(|T[a-zA-Z0-9-_\'\"]#))#|reset)[[:space:]]# && $_p9k__status == 0 ]]
		then
			P9K_TTY=new 
		elif [[ $P9K_TTY == new && $_p9k__fully_initialized == 1 ]] && ! zle
		then
			P9K_TTY=old 
		fi
		_p9k__timer_start=0 
		_p9k__region_active=0 
		unset _p9k__line_finished _p9k__preexec_cmd
		_p9k__keymap=main 
		_p9k__zle_state=insert 
		(( ++_p9k__prompt_idx ))
		if (( $+_p9k__iterm_cmd ))
		then
			_p9k_iterm2_precmd $__p9k_new_status
		fi
	fi
	_p9k_fetch_cwd
	_p9k__refresh_reason=precmd 
	__p9k_reset_state=1 
	local -i fast_vcs
	if (( _p9k_vcs_index && $+GITSTATUS_DAEMON_PID_POWERLEVEL9K ))
	then
		if [[ $_p9k__cwd != $~_POWERLEVEL9K_VCS_DISABLED_DIR_PATTERN ]]
		then
			local -F start_time=EPOCHREALTIME 
			unset _p9k__vcs
			unset _p9k__vcs_timeout
			local -i _p9k__vcs_called
			_p9k_vcs_gitstatus
			local -i fast_vcs=1 
		fi
	fi
	(( $+functions[_p9k_async_segments_compute] )) && _p9k_async_segments_compute
	_p9k__expanded=0 
	_p9k_set_prompt
	_p9k__refresh_reason='' 
	if [[ $precmd_functions[1] != _p9k_do_nothing && $precmd_functions[(I)_p9k_do_nothing] != 0 ]]
	then
		precmd_functions=(_p9k_do_nothing ${(@)precmd_functions:#_p9k_do_nothing}) 
	fi
	if [[ $precmd_functions[-1] != _p9k_precmd && $precmd_functions[(I)_p9k_precmd] != 0 ]]
	then
		precmd_functions=(${(@)precmd_functions:#_p9k_precmd} _p9k_precmd) 
	fi
	if [[ $preexec_functions[1] != _p9k_preexec1 && $preexec_functions[(I)_p9k_preexec1] != 0 ]]
	then
		preexec_functions=(_p9k_preexec1 ${(@)preexec_functions:#_p9k_preexec1}) 
	fi
	if [[ $preexec_functions[-1] != _p9k_preexec2 && $preexec_functions[(I)_p9k_preexec2] != 0 ]]
	then
		preexec_functions=(${(@)preexec_functions:#_p9k_preexec2} _p9k_preexec2) 
	fi
	if (( fast_vcs && _p9k_vcs_index && $+GITSTATUS_DAEMON_PID_POWERLEVEL9K ))
	then
		if (( $+_p9k__vcs_timeout ))
		then
			(( _p9k__vcs_timeout = _POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS + start_time - EPOCHREALTIME ))
			(( _p9k__vcs_timeout >= 0 )) || (( _p9k__vcs_timeout = 0 ))
			gitstatus_process_results_p9k_ -t $_p9k__vcs_timeout POWERLEVEL9K
		fi
		if (( ! $+_p9k__vcs ))
		then
			local _p9k__prompt _p9k__prompt_side=$_p9k_vcs_side _p9k__segment_name=vcs 
			local -i _p9k__has_upglob _p9k__segment_index=_p9k_vcs_index _p9k__line_index=_p9k_vcs_line_index 
			_p9k_vcs_render
			typeset -g _p9k__vcs=$_p9k__prompt 
		fi
	fi
	_p9k_worker_receive
	__p9k_reset_state=0 
}
_p9k_preexec1 () {
	_p9k_restore_special_params
	unset __p9k_trapint
	trap - INT
}
_p9k_preexec2 () {
	typeset -g _p9k__preexec_cmd=$2 
	_p9k__timer_start=EPOCHREALTIME 
	P9K_TTY=old 
	(( ! $+_p9k__iterm_cmd )) || _p9k_iterm2_preexec "$1"
}
_p9k_preinit () {
	(( 1 )) || {
		unfunction _p9k_preinit
		return 1
	}
	[[ $ZSH_VERSION == 5.9 ]] || return
	[[ -r /nix/store/gnwfrf0rn9xx5h5gj1sbhlm8w76iqv2n-powerlevel10k-1.20.15/share/zsh/themes/powerlevel10k/gitstatus/gitstatus.plugin.zsh ]] || return
	builtin source /nix/store/gnwfrf0rn9xx5h5gj1sbhlm8w76iqv2n-powerlevel10k-1.20.15/share/zsh/themes/powerlevel10k/gitstatus/gitstatus.plugin.zsh _p9k_ || return
	GITSTATUS_AUTO_INSTALL='' GITSTATUS_DAEMON=/nix/store/13mfs3cqbya42wy55s88275g8m4b4z5y-gitstatus-1.5.5/bin/gitstatusd GITSTATUS_CACHE_DIR='' GITSTATUS_NUM_THREADS='' GITSTATUS_LOG_LEVEL='' GITSTATUS_ENABLE_LOGGING='' gitstatus_start_p9k_ -s 1 -u 1 -d 1 -c 1 -m -1 -a POWERLEVEL9K
}
_p9k_print_params () {
	typeset -p -- "$@"
}
_p9k_prompt_anaconda_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${CONDA_PREFIX:-$CONDA_ENV_PATH}'
}
_p9k_prompt_asdf_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[asdf]:-${${+functions[asdf]}:#0}}'
}
_p9k_prompt_aws_eb_env_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[eb]'
}
_p9k_prompt_aws_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${AWS_SSO_PROFILE:-${AWS_VAULT:-${AWSUME_PROFILE:-${AWS_PROFILE:-$AWS_DEFAULT_PROFILE}}}}'
}
_p9k_prompt_azure_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[az]'
}
_p9k_prompt_battery_async () {
	local prev="${(pj:\0:)_p9k__battery_args}" 
	_p9k_prompt_battery_set_args
	[[ "${(pj:\0:)_p9k__battery_args}" == $prev ]] && return 1
	_p9k_print_params _p9k__battery_args
	echo -E - 'reset=2'
}
_p9k_prompt_battery_compute () {
	_p9k_worker_async _p9k_prompt_battery_async _p9k_prompt_battery_sync
}
_p9k_prompt_battery_init () {
	typeset -ga _p9k__battery_args=() 
	if [[ $_p9k_os == OSX && $+commands[pmset] == 1 ]]
	then
		_p9k__async_segments_compute+='_p9k_worker_invoke battery _p9k_prompt_battery_compute' 
		return
	fi
	if [[ $_p9k_os != (Linux|Android) || -z /sys/class/power_supply/(CMB*|BAT*|*battery)/(energy_full|charge_full|charge_counter)(#qN) ]]
	then
		typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${:-}'
	fi
}
_p9k_prompt_battery_set_args () {
	_p9k__battery_args=() 
	local state remain
	local -i bat_percent
	case $_p9k_os in
		(OSX) (( $+commands[pmset] )) || return
			local raw_data=${${(Af)"$(pmset -g batt 2>/dev/null)"}[2]} 
			[[ $raw_data == *InternalBattery* ]] || return
			remain=${${(s: :)${${(s:; :)raw_data}[3]}}[1]} 
			[[ $remain == *no* ]] && remain="..." 
			[[ $raw_data =~ '([0-9]+)%' ]] && bat_percent=$match[1] 
			case "${${(s:; :)raw_data}[2]}" in
				('charging' | 'finishing charge' | 'AC attached') if (( bat_percent == 100 ))
					then
						state=CHARGED 
						remain='' 
					else
						state=CHARGING 
					fi ;;
				('discharging') (( bat_percent < _POWERLEVEL9K_BATTERY_LOW_THRESHOLD )) && state=LOW  || state=DISCONNECTED  ;;
				(*) state=CHARGED 
					remain=''  ;;
			esac ;;
		(Linux | Android) local -a bats=(/sys/class/power_supply/(CMB*|BAT*|*battery)/(FN)) 
			(( $#bats )) || return
			local -i energy_now energy_full power_now
			local -i is_full=1 is_calculating is_charching 
			local dir
			for dir in $bats
			do
				_p9k_read_file $dir/status(N) && local bat_status=$_p9k__ret  || continue
				[[ $bat_status == Unknown ]] && continue
				local -i pow=0 full=0 
				if _p9k_read_file $dir/(energy_full|charge_full|charge_counter)(N)
				then
					(( energy_full += ${full::=_p9k__ret} ))
				fi
				if _p9k_read_file $dir/(power|current)_now(N) && (( $#_p9k__ret < 9 ))
				then
					(( power_now += ${pow::=$_p9k__ret} ))
				fi
				if _p9k_read_file $dir/capacity(N)
				then
					(( energy_now += _p9k__ret * full / 100. + 0.5 ))
				elif _p9k_read_file $dir/(energy|charge)_now(N)
				then
					(( energy_now += _p9k__ret ))
				fi
				[[ $bat_status != Full ]] && is_full=0 
				[[ $bat_status == Charging ]] && is_charching=1 
				[[ $bat_status == (Charging|Discharging) && $pow == 0 ]] && is_calculating=1 
			done
			(( energy_full )) || return
			bat_percent=$(( 100. * energy_now / energy_full + 0.5 )) 
			(( bat_percent > 100 )) && bat_percent=100 
			if (( is_full || (bat_percent == 100 && is_charching) ))
			then
				state=CHARGED 
			else
				if (( is_charching ))
				then
					state=CHARGING 
				elif (( bat_percent < _POWERLEVEL9K_BATTERY_LOW_THRESHOLD ))
				then
					state=LOW 
				else
					state=DISCONNECTED 
				fi
				if (( power_now > 0 ))
				then
					(( is_charching )) && local -i e=$((energy_full - energy_now))  || local -i e=energy_now 
					local -i minutes=$(( 60 * e / power_now )) 
					(( minutes > 0 )) && remain=$((minutes/60)):${(l#2##0#)$((minutes%60))} 
				elif (( is_calculating ))
				then
					remain="..." 
				fi
			fi ;;
		(*) return 0 ;;
	esac
	(( bat_percent >= _POWERLEVEL9K_BATTERY_${state}_HIDE_ABOVE_THRESHOLD )) && return
	local msg="$bat_percent%%" 
	[[ $_POWERLEVEL9K_BATTERY_VERBOSE == 1 && -n $remain ]] && msg+=" ($remain)" 
	local icon=BATTERY_ICON 
	local var=_POWERLEVEL9K_BATTERY_${state}_STAGES 
	local -i idx="${#${(@P)var}}" 
	if (( idx ))
	then
		(( bat_percent < 100 )) && idx=$((bat_percent * idx / 100 + 1)) 
		icon=$'\1'"${${(@P)var}[idx]}" 
	fi
	local bg=$_p9k_color1 
	local var=_POWERLEVEL9K_BATTERY_${state}_LEVEL_BACKGROUND 
	local -i idx="${#${(@P)var}}" 
	if (( idx ))
	then
		(( bat_percent < 100 )) && idx=$((bat_percent * idx / 100 + 1)) 
		bg="${${(@P)var}[idx]}" 
	fi
	local fg=$_p9k_battery_states[$state] 
	local var=_POWERLEVEL9K_BATTERY_${state}_LEVEL_FOREGROUND 
	local -i idx="${#${(@P)var}}" 
	if (( idx ))
	then
		(( bat_percent < 100 )) && idx=$((bat_percent * idx / 100 + 1)) 
		fg="${${(@P)var}[idx]}" 
	fi
	_p9k__battery_args=(prompt_battery_$state "$bg" "$fg" $icon 0 '' $msg) 
}
_p9k_prompt_battery_sync () {
	eval $REPLY
	_p9k_worker_reply $REPLY
}
_p9k_prompt_chezmoi_shell_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$CHEZMOI'
}
_p9k_prompt_chruby_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$RUBY_ENGINE'
}
_p9k_prompt_context_init () {
	if [[ $_POWERLEVEL9K_ALWAYS_SHOW_CONTEXT == 0 && -n $DEFAULT_USER && $P9K_SSH == 0 ]]
	then
		if [[ ${(%):-%n} == $DEFAULT_USER ]]
		then
			if (( ! _POWERLEVEL9K_ALWAYS_SHOW_USER ))
			then
				typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${:-}'
			fi
		fi
	fi
}
_p9k_prompt_cpu_arch_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[machine]$commands[arch]'
}
_p9k_prompt_detect_virt_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[systemd-detect-virt]'
}
_p9k_prompt_direnv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${DIRENV_DIR-${precmd_functions[-1]:#_p9k_precmd}}'
}
_p9k_prompt_disk_usage_async () {
	local pct=${${=${(f)"$(df -P $1 2>/dev/null)"}[2]}[5]%%%} 
	[[ $pct == <0-100> && $pct != $_p9k__disk_usage_pct ]] || return
	_p9k__disk_usage_pct=$pct 
	_p9k__disk_usage_normal= 
	_p9k__disk_usage_warning= 
	_p9k__disk_usage_critical= 
	if (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL ))
	then
		_p9k__disk_usage_critical=1 
	elif (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL ))
	then
		_p9k__disk_usage_warning=1 
	elif (( ! _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING ))
	then
		_p9k__disk_usage_normal=1 
	fi
	_p9k_print_params _p9k__disk_usage_pct _p9k__disk_usage_normal _p9k__disk_usage_warning _p9k__disk_usage_critical
	echo -E - 'reset=1'
}
_p9k_prompt_disk_usage_compute () {
	(( $+commands[df] )) || return
	_p9k_worker_async "_p9k_prompt_disk_usage_async ${(q)1}" _p9k_prompt_disk_usage_sync
}
_p9k_prompt_disk_usage_init () {
	typeset -g _p9k__disk_usage_pct= 
	typeset -g _p9k__disk_usage_normal= 
	typeset -g _p9k__disk_usage_warning= 
	typeset -g _p9k__disk_usage_critical= 
	_p9k__async_segments_compute+='_p9k_worker_invoke disk_usage "_p9k_prompt_disk_usage_compute ${(q)_p9k__cwd_a}"' 
}
_p9k_prompt_disk_usage_sync () {
	eval $REPLY
	_p9k_worker_reply $REPLY
}
_p9k_prompt_docker_machine_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$DOCKER_MACHINE_NAME'
}
_p9k_prompt_dotnet_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[dotnet]'
}
_p9k_prompt_dropbox_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[dropbox-cli]'
}
_p9k_prompt_fvm_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[fvm]'
}
_p9k_prompt_gcloud_async () {
	local gcloud=$1 
	$gcloud projects describe $P9K_GCLOUD_PROJECT_ID --configuration=$P9K_GCLOUD_CONFIGURATION --account=$P9K_GCLOUD_ACCOUNT --format='value(name)'
}
_p9k_prompt_gcloud_compute () {
	local gcloud=$1 
	P9K_GCLOUD_CONFIGURATION=$2 
	P9K_GCLOUD_ACCOUNT=$3 
	P9K_GCLOUD_PROJECT_ID=$4 
	_p9k_worker_async "_p9k_prompt_gcloud_async ${(q)gcloud}" _p9k_prompt_gcloud_sync
}
_p9k_prompt_gcloud_init () {
	_p9k__async_segments_compute+=_p9k_gcloud_prefetch 
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[gcloud]'
}
_p9k_prompt_gcloud_sync () {
	_p9k_worker_reply "_p9k_prompt_gcloud_update ${(q)P9K_GCLOUD_CONFIGURATION} ${(q)P9K_GCLOUD_ACCOUNT} ${(q)P9K_GCLOUD_PROJECT_ID} ${(q)REPLY%$'\n'}"
}
_p9k_prompt_gcloud_update () {
	[[ $1 == $P9K_GCLOUD_CONFIGURATION && $2 == $P9K_GCLOUD_ACCOUNT && $3 == $P9K_GCLOUD_PROJECT_ID && $4 != $P9K_GCLOUD_PROJECT_NAME ]] || return
	[[ -n $4 ]] && P9K_GCLOUD_PROJECT_NAME=$4  || unset P9K_GCLOUD_PROJECT_NAME
	_p9k_gcloud_project_name=$P9K_GCLOUD_PROJECT_NAME 
	_p9k__state_dump_scheduled=1 
	reset=1 
}
_p9k_prompt_go_version_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[go]'
}
_p9k_prompt_goenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[goenv]:-${${+functions[goenv]}:#0}}'
}
_p9k_prompt_google_app_cred_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${GOOGLE_APPLICATION_CREDENTIALS:+$commands[jq]}'
}
_p9k_prompt_haskell_stack_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[stack]'
}
_p9k_prompt_java_version_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[java]'
}
_p9k_prompt_jenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[jenv]:-${${+functions[jenv]}:#0}}'
}
_p9k_prompt_kubecontext_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[kubectl]'
}
_p9k_prompt_laravel_version_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[php]'
}
_p9k_prompt_length () {
	local -i COLUMNS=1024 
	local -i x y=${#1} m 
	if (( y ))
	then
		while (( ${${(%):-$1%$y(l.1.0)}[-1]} ))
		do
			x=y 
			(( y *= 2 ))
		done
		while (( y > x + 1 ))
		do
			(( m = x + (y - x) / 2 ))
			(( ${${(%):-$1%$m(l.x.y)}[-1]} = m ))
		done
	fi
	typeset -g _p9k__ret=$x 
}
_p9k_prompt_lf_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${LF_LEVEL:#0}'
}
_p9k_prompt_load_async () {
	local load="$(sysctl -n vm.loadavg 2>/dev/null)"  || return
	load=${${(A)=load}[_POWERLEVEL9K_LOAD_WHICH+1]//,/.} 
	[[ $load == <->(|.<->) && $load != $_p9k__load_value ]] || return
	_p9k__load_value=$load 
	_p9k__load_normal= 
	_p9k__load_warning= 
	_p9k__load_critical= 
	local -F pct='100. * _p9k__load_value / _p9k_num_cpus' 
	if (( pct > _POWERLEVEL9K_LOAD_CRITICAL_PCT ))
	then
		_p9k__load_critical=1 
	elif (( pct > _POWERLEVEL9K_LOAD_WARNING_PCT ))
	then
		_p9k__load_warning=1 
	else
		_p9k__load_normal=1 
	fi
	_p9k_print_params _p9k__load_value _p9k__load_normal _p9k__load_warning _p9k__load_critical
	echo -E - 'reset=1'
}
_p9k_prompt_load_compute () {
	(( $+commands[sysctl] )) || return
	_p9k_worker_async _p9k_prompt_load_async _p9k_prompt_load_sync
}
_p9k_prompt_load_init () {
	if [[ $_p9k_os == (OSX|BSD) ]]
	then
		typeset -g _p9k__load_value= 
		typeset -g _p9k__load_normal= 
		typeset -g _p9k__load_warning= 
		typeset -g _p9k__load_critical= 
		_p9k__async_segments_compute+='_p9k_worker_invoke load _p9k_prompt_load_compute' 
	elif [[ ! -r /proc/loadavg ]]
	then
		typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${:-}'
	fi
}
_p9k_prompt_load_sync () {
	eval $REPLY
	_p9k_worker_reply $REPLY
}
_p9k_prompt_luaenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[luaenv]:-${${+functions[luaenv]}:#0}}'
}
_p9k_prompt_midnight_commander_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$MC_TMPDIR'
}
_p9k_prompt_net_iface_async () {
	local iface ip line var
	typeset -a iface2ip ips ifaces
	if (( $+commands[ip] )) && [[ $+commands[ifconfig] == 0 || $OSTYPE == linux* ]]
	then
		for line in ${(f)"$(command ip -4 a show 2>/dev/null)"}
		do
			if [[ $line == (#b)<->:[[:space:]]##([^:]##):[[:space:]]##\<([^\>]#)\>* ]]
			then
				[[ ,$match[2], == *,UP,* ]] && iface=$match[1]  || iface= 
			elif [[ -n $iface && $line == (#b)[[:space:]]##inet[[:space:]]##([0-9.]##)* ]]
			then
				iface2ip+=($iface $match[1]) 
				iface= 
			fi
		done
	elif (( $+commands[ifconfig] ))
	then
		for line in ${(f)"$(command ifconfig 2>/dev/null)"}
		do
			if [[ $line == (#b)([^[:space:]]##):[[:space:]]##flags=([[:xdigit:]]##)'<'* ]]
			then
				[[ $match[2] == *[13579bdfBDF] ]] && iface=$match[1]  || iface= 
			elif [[ -n $iface && $line == (#b)[[:space:]]##inet[[:space:]]##([0-9.]##)* ]]
			then
				iface2ip+=($iface $match[1]) 
				iface= 
			fi
		done
	fi
	if _p9k_prompt_net_iface_match $_POWERLEVEL9K_PUBLIC_IP_VPN_INTERFACE
	then
		local public_ip_vpn=1 
		local public_ip_not_vpn= 
	else
		local public_ip_vpn= 
		local public_ip_not_vpn=1 
	fi
	if _p9k_prompt_net_iface_match $_POWERLEVEL9K_IP_INTERFACE
	then
		local ip_ip=$ips[1] ip_interface=$ifaces[1] ip_timestamp=$EPOCHREALTIME 
		local ip_tx_bytes ip_rx_bytes ip_tx_rate ip_rx_rate
		if [[ $_p9k_os == (Linux|Android) ]]
		then
			if [[ -r /sys/class/net/$ifaces[1]/statistics/tx_bytes && -r /sys/class/net/$ifaces[1]/statistics/rx_bytes ]]
			then
				_p9k_read_file /sys/class/net/$ifaces[1]/statistics/tx_bytes && [[ $_p9k__ret == <-> ]] && ip_tx_bytes=$_p9k__ret  && _p9k_read_file /sys/class/net/$ifaces[1]/statistics/rx_bytes && [[ $_p9k__ret == <-> ]] && ip_rx_bytes=$_p9k__ret  || {
					ip_tx_bytes= 
					ip_rx_bytes= 
				}
			fi
		elif [[ $_p9k_os == (BSD|OSX) && $+commands[netstat] == 1 ]]
		then
			local -a lines
			if lines=(${(f)"$(netstat -inbI $ifaces[1])"}) 
			then
				local header=($=lines[1]) 
				local -i rx_idx=$header[(Ie)Ibytes] 
				local -i tx_idx=$header[(Ie)Obytes] 
				if (( rx_idx && tx_idx ))
				then
					ip_tx_bytes=0 
					ip_rx_bytes=0 
					for line in ${lines:1}
					do
						(( ip_rx_bytes += ${line[(w)rx_idx]} ))
						(( ip_tx_bytes += ${line[(w)tx_idx]} ))
					done
				fi
			fi
		fi
		if [[ -n $ip_rx_bytes ]]
		then
			if [[ $ip_ip == $P9K_IP_IP && $ifaces[1] == $P9K_IP_INTERFACE ]]
			then
				local -F t='ip_timestamp - _p9__ip_timestamp' 
				if (( t <= 0 ))
				then
					ip_tx_rate=${P9K_IP_TX_RATE:-0 B/s} 
					ip_rx_rate=${P9K_IP_RX_RATE:-0 B/s} 
				else
					_p9k_human_readable_bytes $(((ip_tx_bytes - P9K_IP_TX_BYTES) / t))
					[[ $_p9k__ret == *B ]] && ip_tx_rate="$_p9k__ret[1,-2] B/s"  || ip_tx_rate="$_p9k__ret[1,-2] $_p9k__ret[-1]iB/s" 
					_p9k_human_readable_bytes $(((ip_rx_bytes - P9K_IP_RX_BYTES) / t))
					[[ $_p9k__ret == *B ]] && ip_rx_rate="$_p9k__ret[1,-2] B/s"  || ip_rx_rate="$_p9k__ret[1,-2] $_p9k__ret[-1]iB/s" 
				fi
			else
				ip_tx_rate='0 B/s' 
				ip_rx_rate='0 B/s' 
			fi
		fi
	else
		local ip_ip= ip_interface= ip_tx_bytes= ip_rx_bytes= ip_tx_rate= ip_rx_rate= ip_timestamp= 
	fi
	if _p9k_prompt_net_iface_match $_POWERLEVEL9K_VPN_IP_INTERFACE
	then
		if (( _POWERLEVEL9K_VPN_IP_SHOW_ALL ))
		then
			local vpn_ip_ips=($ips) 
		else
			local vpn_ip_ips=($ips[1]) 
		fi
	else
		local vpn_ip_ips=() 
	fi
	[[ $_p9k__public_ip_vpn == $public_ip_vpn && $_p9k__public_ip_not_vpn == $public_ip_not_vpn && $P9K_IP_IP == $ip_ip && $P9K_IP_INTERFACE == $ip_interface && $P9K_IP_TX_BYTES == $ip_tx_bytes && $P9K_IP_RX_BYTES == $ip_rx_bytes && $P9K_IP_TX_RATE == $ip_tx_rate && $P9K_IP_RX_RATE == $ip_rx_rate && "$_p9k__vpn_ip_ips" == "$vpn_ip_ips" ]] && return 1
	if [[ "$_p9k__vpn_ip_ips" == "$vpn_ip_ips" ]]
	then
		echo -n 0
	else
		echo -n 1
	fi
	_p9k__public_ip_vpn=$public_ip_vpn 
	_p9k__public_ip_not_vpn=$public_ip_not_vpn 
	P9K_IP_IP=$ip_ip 
	P9K_IP_INTERFACE=$ip_interface 
	if [[ -n $ip_tx_bytes && -n $P9K_IP_TX_BYTES ]]
	then
		P9K_IP_TX_BYTES_DELTA=$((ip_tx_bytes - P9K_IP_TX_BYTES)) 
	else
		P9K_IP_TX_BYTES_DELTA= 
	fi
	if [[ -n $ip_rx_bytes && -n $P9K_IP_RX_BYTES ]]
	then
		P9K_IP_RX_BYTES_DELTA=$((ip_rx_bytes - P9K_IP_RX_BYTES)) 
	else
		P9K_IP_RX_BYTES_DELTA= 
	fi
	P9K_IP_TX_BYTES=$ip_tx_bytes 
	P9K_IP_RX_BYTES=$ip_rx_bytes 
	P9K_IP_TX_RATE=$ip_tx_rate 
	P9K_IP_RX_RATE=$ip_rx_rate 
	_p9__ip_timestamp=$ip_timestamp 
	_p9k__vpn_ip_ips=($vpn_ip_ips) 
	_p9k_print_params _p9k__public_ip_vpn _p9k__public_ip_not_vpn P9K_IP_IP P9K_IP_INTERFACE P9K_IP_TX_BYTES P9K_IP_RX_BYTES P9K_IP_TX_BYTES_DELTA P9K_IP_RX_BYTES_DELTA P9K_IP_TX_RATE P9K_IP_RX_RATE _p9__ip_timestamp _p9k__vpn_ip_ips
	echo -E - 'reset=1'
}
_p9k_prompt_net_iface_compute () {
	_p9k_worker_async _p9k_prompt_net_iface_async _p9k_prompt_net_iface_sync
}
_p9k_prompt_net_iface_init () {
	typeset -g _p9k__public_ip_vpn= 
	typeset -g _p9k__public_ip_not_vpn= 
	typeset -g P9K_IP_IP= 
	typeset -g P9K_IP_INTERFACE= 
	typeset -g P9K_IP_TX_BYTES= 
	typeset -g P9K_IP_RX_BYTES= 
	typeset -g P9K_IP_TX_BYTES_DELTA= 
	typeset -g P9K_IP_RX_BYTES_DELTA= 
	typeset -g P9K_IP_TX_RATE= 
	typeset -g P9K_IP_RX_RATE= 
	typeset -g _p9__ip_timestamp= 
	typeset -g _p9k__vpn_ip_ips=() 
	[[ -z $_POWERLEVEL9K_PUBLIC_IP_VPN_INTERFACE ]] && _p9k__public_ip_not_vpn=1 
	_p9k__async_segments_compute+='_p9k_worker_invoke net_iface _p9k_prompt_net_iface_compute' 
}
_p9k_prompt_net_iface_match () {
	local iface_regex="^($1)\$" iface ip 
	ips=() 
	ifaces=() 
	for iface ip in "${(@)iface2ip}"
	do
		[[ $iface =~ $iface_regex ]] || continue
		ifaces+=$iface 
		ips+=$ip 
	done
	return $(($#ips == 0))
}
_p9k_prompt_net_iface_sync () {
	local -i vpn_ip_changed=$REPLY[1] 
	REPLY[1]="" 
	eval $REPLY
	(( vpn_ip_changed )) && REPLY+='; _p9k_vpn_ip_render' 
	_p9k_worker_reply $REPLY
}
_p9k_prompt_nix_shell_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k_nix_shell_cond
}
_p9k_prompt_nnn_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${NNNLVL:#0}'
}
_p9k_prompt_node_version_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[node]'
}
_p9k_prompt_nodeenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$NODE_VIRTUAL_ENV'
}
_p9k_prompt_nodenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[nodenv]:-${${+functions[nodenv]}:#0}}'
}
_p9k_prompt_nordvpn_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[nordvpn]'
}
_p9k_prompt_nvm_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[nvm]:-${${+functions[nvm]}:#0}}'
}
_p9k_prompt_openfoam_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$WM_PROJECT_VERSION'
}
_p9k_prompt_overflow_bug () {
	[[ $ZSH_PATCHLEVEL =~ '^zsh-5\.4\.2-([0-9]+)-' ]] && return $(( match[1] < 159 ))
	[[ $ZSH_PATCHLEVEL =~ '^zsh-5\.7\.1-([0-9]+)-' ]] && return $(( match[1] >= 50 ))
	[[ $ZSH_VERSION == 5.<5-7>* && $ZSH_VERSION != 5.7.<2->* ]]
}
_p9k_prompt_per_directory_history_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$PER_DIRECTORY_HISTORY_TOGGLE'
}
_p9k_prompt_perlbrew_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$PERLBREW_PERL'
}
_p9k_prompt_php_version_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[php]'
}
_p9k_prompt_phpenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[phpenv]:-${${+functions[phpenv]}:#0}}'
}
_p9k_prompt_plenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[plenv]:-${${+functions[plenv]}:#0}}'
}
_p9k_prompt_proxy_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$all_proxy$http_proxy$https_proxy$ftp_proxy$ALL_PROXY$HTTP_PROXY$HTTPS_PROXY$FTP_PROXY'
}
_p9k_prompt_public_ip_async () {
	local ip method
	local -F start=EPOCHREALTIME 
	local -F next='start + 5' 
	for method in $_POWERLEVEL9K_PUBLIC_IP_METHODS $_POWERLEVEL9K_PUBLIC_IP_METHODS
	do
		case $method in
			(dig) if (( $+commands[dig] ))
				then
					ip="$(dig +tries=1 +short -4 A myip.opendns.com @resolver1.opendns.com 2>/dev/null)" 
					[[ $ip == ';'* ]] && ip= 
					if [[ -z $ip ]]
					then
						ip="$(dig +tries=1 +short -6 AAAA myip.opendns.com @resolver1.opendns.com 2>/dev/null)" 
						[[ $ip == ';'* ]] && ip= 
					fi
				fi ;;
			(curl) if (( $+commands[curl] ))
				then
					ip="$(curl --max-time 5 -w '\n' "$_POWERLEVEL9K_PUBLIC_IP_HOST" 2>/dev/null)" 
				fi ;;
			(wget) if (( $+commands[wget] ))
				then
					ip="$(wget -T 5 -qO- "$_POWERLEVEL9K_PUBLIC_IP_HOST" 2>/dev/null)" 
				fi ;;
		esac
		[[ $ip =~ '^[0-9a-f.:]+$' ]] || ip='' 
		if [[ -n $ip ]]
		then
			next=$((start + _POWERLEVEL9K_PUBLIC_IP_TIMEOUT)) 
			break
		fi
	done
	_p9k__public_ip_next_time=$next 
	_p9k_print_params _p9k__public_ip_next_time
	[[ $_p9k__public_ip == $ip ]] && return
	_p9k__public_ip=$ip 
	_p9k_print_params _p9k__public_ip
	echo -E - 'reset=1'
}
_p9k_prompt_public_ip_compute () {
	(( EPOCHREALTIME >= _p9k__public_ip_next_time )) || return
	_p9k_worker_async _p9k_prompt_public_ip_async _p9k_prompt_public_ip_sync
}
_p9k_prompt_public_ip_init () {
	typeset -g _p9k__public_ip= 
	typeset -gF _p9k__public_ip_next_time=0 
	_p9k__async_segments_compute+='_p9k_worker_invoke public_ip _p9k_prompt_public_ip_compute' 
}
_p9k_prompt_public_ip_sync () {
	eval $REPLY
	_p9k_worker_reply $REPLY
}
_p9k_prompt_pyenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[pyenv]:-${${+functions[pyenv]}:#0}}'
}
_p9k_prompt_ram_async () {
	local -F free_bytes
	case $_p9k_os in
		(OSX) (( $+commands[vm_stat] )) || return
			local stat && stat="$(vm_stat 2>/dev/null)"  || return
			[[ $stat =~ 'Pages free:[[:space:]]+([0-9]+)' ]] || return
			(( free_bytes += match[1] ))
			[[ $stat =~ 'Pages inactive:[[:space:]]+([0-9]+)' ]] || return
			(( free_bytes += match[1] ))
			if (( ! $+_p9k__ram_pagesize ))
			then
				local p
				(( $+commands[pagesize] )) && p=$(pagesize 2>/dev/null)  && [[ $p == <1-> ]] || p=4096 
				typeset -gi _p9k__ram_pagesize=p 
				_p9k_print_params _p9k__ram_pagesize
			fi
			(( free_bytes *= _p9k__ram_pagesize )) ;;
		(BSD) local stat && stat="$(grep -F 'avail memory' /var/run/dmesg.boot 2>/dev/null)"  || return
			free_bytes=${${(A)=stat}[4]}  ;;
		(*) [[ -r /proc/meminfo ]] || return
			local stat && stat="$(</proc/meminfo)"  || return
			[[ $stat == (#b)*(MemAvailable:|MemFree:)[[:space:]]#(<->)* ]] || return
			free_bytes=$(( $match[2] * 1024 ))  ;;
	esac
	_p9k_human_readable_bytes $free_bytes
	[[ $_p9k__ret != $_p9k__ram_free ]] || return
	_p9k__ram_free=$_p9k__ret 
	_p9k_print_params _p9k__ram_free
	echo -E - 'reset=1'
}
_p9k_prompt_ram_compute () {
	_p9k_worker_async _p9k_prompt_ram_async _p9k_prompt_ram_sync
}
_p9k_prompt_ram_init () {
	if [[ ( $_p9k_os == OSX && $+commands[vm_stat] == 0 ) || ( $_p9k_os == BSD && ! -r /var/run/dmesg.boot ) || ( $_p9k_os != (OSX|BSD) && ! -r /proc/meminfo ) ]]
	then
		typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${:-}'
		return
	fi
	typeset -g _p9k__ram_free= 
	_p9k__async_segments_compute+='_p9k_worker_invoke ram _p9k_prompt_ram_compute' 
}
_p9k_prompt_ram_sync () {
	eval $REPLY
	_p9k_worker_reply $REPLY
}
_p9k_prompt_ranger_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$RANGER_LEVEL'
}
_p9k_prompt_rbenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[rbenv]:-${${+functions[rbenv]}:#0}}'
}
_p9k_prompt_rust_version_async () {
	typeset -g P9K_RUST_VERSION=$1 
	local rustc=$2 cwd=$3 v 
	if pushd -q -- $cwd
	then
		{
			v=${${"$($rustc --version)"#rustc }%% *}  || v= 
		} always {
			popd -q
		}
	fi
	[[ $v != $P9K_RUST_VERSION ]] || return
	typeset -g P9K_RUST_VERSION=$v 
	_p9k_print_params P9K_RUST_VERSION
	echo -E - 'reset=1'
}
_p9k_prompt_rust_version_compute () {
	_p9k_worker_async "_p9k_prompt_rust_version_async ${(q)1} ${(q)2} ${(q)3}" _p9k_prompt_rust_version_sync
}
_p9k_prompt_rust_version_init () {
	_p9k__async_segments_compute+='_p9k_rust_version_prefetch' 
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[rustc]'
}
_p9k_prompt_rust_version_sync () {
	if [[ -n $REPLY ]]
	then
		eval $REPLY
		_p9k_worker_reply $REPLY
	fi
}
_p9k_prompt_rvm_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[rvm-prompt]:-${${+functions[rvm-prompt]}:#0}}'
}
_p9k_prompt_scalaenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[scalaenv]:-${${+functions[scalaenv]}:#0}}'
}
_p9k_prompt_segment () {
	"_p9k_${_p9k__prompt_side}_prompt_segment" "$@"
}
_p9k_prompt_ssh_init () {
	if (( ! P9K_SSH ))
	then
		typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${:-}'
	fi
}
_p9k_prompt_swap_async () {
	local -F used_bytes
	if [[ "$_p9k_os" == "OSX" ]]
	then
		(( $+commands[sysctl] )) || return
		[[ "$(sysctl vm.swapusage 2>/dev/null)" =~ "used = ([0-9,.]+)([A-Z]+)" ]] || return
		used_bytes=${match[1]//,/.} 
		case ${match[2]} in
			('K') (( used_bytes *= 1024 )) ;;
			('M') (( used_bytes *= 1048576 )) ;;
			('G') (( used_bytes *= 1073741824 )) ;;
			('T') (( used_bytes *= 1099511627776 )) ;;
			(*) return 0 ;;
		esac
	else
		local meminfo && meminfo="$(grep -F 'Swap' /proc/meminfo 2>/dev/null)"  || return
		[[ $meminfo =~ 'SwapTotal:[[:space:]]+([0-9]+)' ]] || return
		(( used_bytes+=match[1] ))
		[[ $meminfo =~ 'SwapFree:[[:space:]]+([0-9]+)' ]] || return
		(( used_bytes-=match[1] ))
		(( used_bytes *= 1024 ))
	fi
	(( used_bytes >= 0 || (used_bytes = 0) ))
	_p9k_human_readable_bytes $used_bytes
	[[ $_p9k__ret != $_p9k__swap_used ]] || return
	_p9k__swap_used=$_p9k__ret 
	_p9k_print_params _p9k__swap_used
	echo -E - 'reset=1'
}
_p9k_prompt_swap_compute () {
	_p9k_worker_async _p9k_prompt_swap_async _p9k_prompt_swap_sync
}
_p9k_prompt_swap_init () {
	if [[ ( $_p9k_os == OSX && $+commands[sysctl] == 0 ) || ( $_p9k_os != OSX && ! -r /proc/meminfo ) ]]
	then
		typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${:-}'
		return
	fi
	typeset -g _p9k__swap_used= 
	_p9k__async_segments_compute+='_p9k_worker_invoke swap _p9k_prompt_swap_compute' 
}
_p9k_prompt_swap_sync () {
	eval $REPLY
	_p9k_worker_reply $REPLY
}
_p9k_prompt_swift_version_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[swift]'
}
_p9k_prompt_taskwarrior_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${commands[task]:+$_p9k__taskwarrior_functional}'
}
_p9k_prompt_terraform_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[terraform]'
}
_p9k_prompt_terraform_version_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[terraform]'
}
_p9k_prompt_time_async () {
	sleep 1 || true
}
_p9k_prompt_time_compute () {
	_p9k_worker_async _p9k_prompt_time_async _p9k_prompt_time_sync
}
_p9k_prompt_time_init () {
	(( _POWERLEVEL9K_EXPERIMENTAL_TIME_REALTIME )) || return
	_p9k__async_segments_compute+='_p9k_worker_invoke time _p9k_prompt_time_compute' 
}
_p9k_prompt_time_sync () {
	_p9k_worker_reply '_p9k_worker_invoke _p9k_prompt_time_compute _p9k_prompt_time_compute; reset=1'
}
_p9k_prompt_timewarrior_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$commands[timew]'
}
_p9k_prompt_todo_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$_p9k__todo_file'
}
_p9k_prompt_toolbox_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$P9K_TOOLBOX_NAME'
}
_p9k_prompt_user_init () {
	if [[ $_POWERLEVEL9K_ALWAYS_SHOW_USER == 0 && "${(%):-%n}" == $DEFAULT_USER ]]
	then
		typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${:-}'
	fi
}
_p9k_prompt_vim_shell_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$VIMRUNTIME'
}
_p9k_prompt_virtualenv_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$VIRTUAL_ENV'
}
_p9k_prompt_wifi_async () {
	local airport=/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport 
	local last_tx_rate ssid link_auth rssi noise bars on out line v state iface
	{
		if [[ -x $airport ]]
		then
			out="$($airport -I)"  || return 0
			for line in ${${${(f)out}##[[:space:]]#}%%[[:space:]]#}
			do
				v=${line#*: } 
				case $line[1,-$#v-3] in
					(agrCtlRSSI) rssi=$v  ;;
					(agrCtlNoise) noise=$v  ;;
					(state) state=$v  ;;
					(lastTxRate) last_tx_rate=$v  ;;
					(link\ auth) link_auth=$v  ;;
					(SSID) ssid=$v  ;;
				esac
			done
			[[ $state == running && $rssi == (0|-<->) && $noise == (0|-<->) ]] || return 0
		elif [[ -r /proc/net/wireless && -n $commands[iw] ]]
		then
			local -a lines
			lines=(${${(f)"$(</proc/net/wireless)"}:#*\|*})  || return 0
			(( $#lines == 1 )) || return 0
			local parts=(${=lines[1]}) 
			iface=${parts[1]%:} 
			state=${parts[2]} 
			rssi=${parts[4]%.*} 
			noise=${parts[5]%.*} 
			[[ -n $iface && $state == 0## && $rssi == (0|-<->) && $noise == (0|-<->) ]] || return 0
			lines=(${(f)"$(command iw dev $iface link)"})  || return 0
			local -a match mbegin mend
			for line in $lines
			do
				if [[ $line == (#b)[[:space:]]#SSID:[[:space:]]##(*) ]]
				then
					ssid=$match[1] 
				elif [[ $line == (#b)[[:space:]]#'tx bitrate:'[[:space:]]##([^[:space:]]##)' MBit/s'* ]]
				then
					last_tx_rate=$match[1] 
					[[ $last_tx_rate == <->.<-> ]] && last_tx_rate=${${last_tx_rate%%0#}%.} 
				fi
			done
			[[ -n $ssid && -n $last_tx_rate ]] || return 0
		else
			return 0
		fi
		local -i snr_margin='rssi - noise' 
		if (( snr_margin >= 40 ))
		then
			bars=4 
		elif (( snr_margin >= 25 ))
		then
			bars=3 
		elif (( snr_margin >= 15 ))
		then
			bars=2 
		elif (( snr_margin >= 10 ))
		then
			bars=1 
		else
			bars=0 
		fi
		on=1 
	} always {
		if (( ! on ))
		then
			rssi= 
			noise= 
			ssid= 
			last_tx_rate= 
			bars= 
			link_auth= 
		fi
		if [[ $_p9k__wifi_on != $on || $P9K_WIFI_LAST_TX_RATE != $last_tx_rate || $P9K_WIFI_SSID != $ssid || $P9K_WIFI_LINK_AUTH != $link_auth || $P9K_WIFI_RSSI != $rssi || $P9K_WIFI_NOISE != $noise || $P9K_WIFI_BARS != $bars ]]
		then
			_p9k__wifi_on=$on 
			P9K_WIFI_LAST_TX_RATE=$last_tx_rate 
			P9K_WIFI_SSID=$ssid 
			P9K_WIFI_LINK_AUTH=$link_auth 
			P9K_WIFI_RSSI=$rssi 
			P9K_WIFI_NOISE=$noise 
			P9K_WIFI_BARS=$bars 
			_p9k_print_params _p9k__wifi_on P9K_WIFI_LAST_TX_RATE P9K_WIFI_SSID P9K_WIFI_LINK_AUTH P9K_WIFI_RSSI P9K_WIFI_NOISE P9K_WIFI_BARS
			echo -E - 'reset=1'
		fi
	}
}
_p9k_prompt_wifi_compute () {
	_p9k_worker_async _p9k_prompt_wifi_async _p9k_prompt_wifi_sync
}
_p9k_prompt_wifi_init () {
	if [[ -x /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport || ( -r /proc/net/wireless && -n $commands[iw] ) ]]
	then
		typeset -g _p9k__wifi_on= 
		typeset -g P9K_WIFI_LAST_TX_RATE= 
		typeset -g P9K_WIFI_SSID= 
		typeset -g P9K_WIFI_LINK_AUTH= 
		typeset -g P9K_WIFI_RSSI= 
		typeset -g P9K_WIFI_NOISE= 
		typeset -g P9K_WIFI_BARS= 
		_p9k__async_segments_compute+='_p9k_worker_invoke wifi _p9k_prompt_wifi_compute' 
	else
		typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='${:-}'
	fi
}
_p9k_prompt_wifi_sync () {
	if [[ -n $REPLY ]]
	then
		eval $REPLY
		_p9k_worker_reply $REPLY
	fi
}
_p9k_prompt_xplr_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$XPLR_PID'
}
_p9k_prompt_yazi_init () {
	typeset -g "_p9k__segment_cond_${_p9k__prompt_side}[_p9k__segment_index]"='$YAZI_LEVEL'
}
_p9k_pyenv_compute () {
	unset P9K_PYENV_PYTHON_VERSION _p9k__pyenv_version
	local v=${(j.:.)${(@)${(s.:.)PYENV_VERSION}#python-}} 
	if [[ -n $v ]]
	then
		(( ${_POWERLEVEL9K_PYENV_SOURCES[(I)shell]} )) || return
	else
		(( ${_POWERLEVEL9K_PYENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $PYENV_DIR != (|.) ]]
		then
			[[ $PYENV_DIR == /* ]] && local dir=$PYENV_DIR  || local dir="$_p9k__cwd_a/$PYENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_pyenv_like_version_file $dir/.python-version python-
					then
						(( ${_POWERLEVEL9K_PYENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .python-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_pyenv_like_version_file $_p9k__parent_dirs[idx]/.python-version python-
			then
				(( ${_POWERLEVEL9K_PYENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_PYENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_PYENV_SOURCES[(I)global]} )) || return
			_p9k_pyenv_global_version
		fi
		v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_PYENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_pyenv_global_version
		[[ $v == $_p9k__ret ]] && return 1
	fi
	if (( !_POWERLEVEL9K_PYENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return 1
	fi
	local versions=${PYENV_ROOT:-$HOME/.pyenv}/versions 
	versions=${versions:A} 
	local name version
	for name in ${(s.:.)v}
	do
		version=$versions/$name 
		version=${version:A} 
		if [[ $version(#qN/) == (#b)$versions/([^/]##)* ]]
		then
			typeset -g P9K_PYENV_PYTHON_VERSION=$match[1] 
			break
		fi
	done
	typeset -g _p9k__pyenv_version=$v 
}
_p9k_pyenv_global_version () {
	_p9k_read_pyenv_like_version_file ${PYENV_ROOT:-$HOME/.pyenv}/version python- || _p9k__ret=system 
}
_p9k_python_version () {
	case $commands[python] in
		("") return 1 ;;
		(${PYENV_ROOT:-~/.pyenv}/shims/python) local P9K_PYENV_PYTHON_VERSION _p9k__pyenv_version
			local -i _POWERLEVEL9K_PYENV_PROMPT_ALWAYS_SHOW=1 _POWERLEVEL9K_PYENV_SHOW_SYSTEM=1 
			local _POWERLEVEL9K_PYENV_SOURCES=(shell local global) 
			if _p9k_pyenv_compute && [[ $P9K_PYENV_PYTHON_VERSION == ([[:digit:].]##)* ]]
			then
				_p9k__ret=$P9K_PYENV_PYTHON_VERSION 
				return 0
			fi ;&
		(*) _p9k_cached_cmd 1 '' python --version || return
			[[ $_p9k__ret == (#b)Python\ ([[:digit:].]##)* ]] && _p9k__ret=$match[1]  ;;
	esac
}
_p9k_rbenv_global_version () {
	_p9k_read_word ${RBENV_ROOT:-$HOME/.rbenv}/version || _p9k__ret=system 
}
_p9k_read_file () {
	_p9k__ret='' 
	[[ -n $1 ]] && IFS='' read -r _p9k__ret < $1
	[[ -n $_p9k__ret ]]
}
_p9k_read_pyenv_like_version_file () {
	local -a stat
	zstat -A stat +mtime -- $1 2> /dev/null || stat=(-1) 
	local cached=$_p9k__read_pyenv_like_version_file_cache[$1:$2] 
	if [[ $cached == $stat[1]:* ]]
	then
		_p9k__ret=${cached#*:} 
	else
		local fd content
		{
			{
				sysopen -r -u fd -- $1 && sysread -i $fd -s 1024 content
			} 2> /dev/null
		} always {
			[[ -n $fd ]] && exec {fd}>&-
		}
		local MATCH
		local versions=(${${${${(f)content}/(#m)*/${MATCH[(w)1]}}##\#*}#$2}) 
		_p9k__ret=${(j.:.)versions} 
		_p9k__read_pyenv_like_version_file_cache[$1:$2]=$stat[1]:$_p9k__ret 
	fi
	[[ -n $_p9k__ret ]]
}
_p9k_read_word () {
	local -a stat
	zstat -A stat +mtime -- $1 2> /dev/null || stat=(-1) 
	local cached=$_p9k__read_word_cache[$1] 
	if [[ $cached == $stat[1]:* ]]
	then
		_p9k__ret=${cached#*:} 
	else
		local rest
		_p9k__ret= 
		{
			read _p9k__ret rest < $1
		} 2> /dev/null
		_p9k__ret=${_p9k__ret%$'\r'} 
		_p9k__read_word_cache[$1]=$stat[1]:$_p9k__ret 
	fi
	[[ -n $_p9k__ret ]]
}
_p9k_redraw () {
	zle -F $1
	exec {1}>&-
	_p9k__redraw_fd=0 
	() {
		local -h WIDGET=zle-line-pre-redraw 
		_p9k_widget_hook ''
	}
}
_p9k_reset_prompt () {
	if (( __p9k_reset_state != 1 )) && zle && [[ -z $_p9k__line_finished ]]
	then
		__p9k_reset_state=0 
		setopt prompt_subst
		(( __p9k_ksh_arrays )) && setopt ksh_arrays
		(( __p9k_sh_glob )) && setopt sh_glob
		{
			(( _p9k__can_hide_cursor )) && echoti civis
			zle .reset-prompt
			(( ${+functions[z4h]} )) || zle -R
		} always {
			(( _p9k__can_hide_cursor )) && print -rn -- $_p9k__cnorm
			_p9k__cursor_hidden=0 
		}
	fi
}
_p9k_restore_prompt () {
	eval "$__p9k_intro"
	zle -F $1
	exec {1}>&-
	_p9k__restore_prompt_fd=0 
	(( _p9k__must_restore_prompt )) || return 0
	_p9k__must_restore_prompt=0 
	unset _p9k__line_finished
	_p9k__refresh_reason=restore 
	_p9k_set_prompt
	_p9k__refresh_reason= 
	_p9k__expanded=0 
	_p9k_reset_prompt
}
_p9k_restore_special_params () {
	(( ! ${+_p9k__real_zle_rprompt_indent} )) || {
		[[ -n "$_p9k__real_zle_rprompt_indent" ]] && ZLE_RPROMPT_INDENT="$_p9k__real_zle_rprompt_indent"  || unset ZLE_RPROMPT_INDENT
		unset _p9k__real_zle_rprompt_indent
	}
	(( ! ${+_p9k__real_lc_ctype} )) || {
		LC_CTYPE="$_p9k__real_lc_ctype" 
		unset _p9k__real_lc_ctype
	}
	(( ! ${+_p9k__real_lc_all} )) || {
		LC_ALL="$_p9k__real_lc_all" 
		unset _p9k__real_lc_all
	}
}
_p9k_restore_state () {
	{
		[[ $__p9k_cached_param_pat == $_p9k__param_pat && $__p9k_cached_param_sig == $_p9k__param_sig ]] || return
		(( $+functions[_p9k_restore_state_impl] )) || return
		_p9k_restore_state_impl
		return 0
	} always {
		if (( $? ))
		then
			if (( $+functions[_p9k_preinit] ))
			then
				unfunction _p9k_preinit
				(( $+functions[gitstatus_stop_p9k_] )) && gitstatus_stop_p9k_ POWERLEVEL9K
			fi
			_p9k_delete_instant_prompt
			zf_rm -f -- $__p9k_dump_file{,.zwc} 2> /dev/null
		elif [[ $__p9k_instant_prompt_param_sig != $_p9k__param_sig ]]
		then
			_p9k_delete_instant_prompt
			_p9k_dumped_instant_prompt_sigs=() 
		fi
		unset __p9k_cached_param_sig
	}
}
_p9k_restore_state_impl () {
	typeset -g -a _POWERLEVEL9K_GOENV_SOURCES=(shell local global) 
	typeset -g -i _POWERLEVEL9K_DISABLE_GITSTATUS=0 
	typeset -g -a _POWERLEVEL9K_BATTERY_DISCONNECTED_LEVEL_BACKGROUND=() 
	typeset -g -i _POWERLEVEL9K_PYENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g -i _POWERLEVEL9K_HASKELL_STACK_PROMPT_ALWAYS_SHOW=1 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_ERROR_VIVIS_FOREGROUND='#FF5C57' 
	typeset -g -a _POWERLEVEL9K_BATTERY_LOW_LEVEL_BACKGROUND=() 
	typeset -g _POWERLEVEL9K_INSTANT_PROMPT=verbose 
	typeset -g -i _POWERLEVEL9K_LUAENV_SHOW_SYSTEM=1 
	typeset -g -a _POWERLEVEL9K_KUBECONTEXT_CLASSES=() 
	typeset -g _p9k_gcloud_account='' 
	typeset -g -a _p9k_asdf_meta_files=() 
	typeset -g -i _POWERLEVEL9K_NODENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g _POWERLEVEL9K_SHORTEN_FOLDER_MARKER='(.bzr|.citc|.git|.hg|.node-version|.python-version|.ruby-version|.shorten_folder_marker|.svn|.terraform|CVS|Cargo.toml|composer.json|go.mod|package.json)' 
	typeset -g -i _POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0 
	typeset -g -i _POWERLEVEL9K_JENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g _POWERLEVEL9K_DIR_FOREGROUND='#57C7FF' 
	typeset -g _POWERLEVEL9K_LEFT_RIGHT_WHITESPACE='' 
	typeset -g -i _POWERLEVEL9K_SCALAENV_SHOW_SYSTEM=1 
	typeset -g -a _POWERLEVEL9K_TERRAFORM_CLASSES=() 
	typeset -g _POWERLEVEL9K_PUBLIC_IP_HOST=https://v4.ident.me/ 
	typeset -g -i _POWERLEVEL9K_ASDF_SHOW_SYSTEM=1 
	typeset -g _p9k_prompt_suffix_right='${${COLUMNS::=$_p9k__clm}+}}' 
	typeset -g -i _p9k_term_has_href=1 
	typeset -g -i _POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=0 
	typeset -g _POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s' 
	typeset -g -i _POWERLEVEL9K_GOENV_SHOW_SYSTEM=1 
	typeset -g _POWERLEVEL9K_ANACONDA_RIGHT_DELIMITER=')' 
	typeset -g -a _p9k_right_join=(1) 
	typeset -g -i _POWERLEVEL9K_LUAENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g _POWERLEVEL9K_GITSTATUS_DIR='' 
	typeset -g _p9k_transient_prompt='' 
	typeset -g _p9k_asdf_meta_sig='' 
	typeset -g -a _POWERLEVEL9K_JENV_SOURCES=(shell local global) 
	typeset -g -i _POWERLEVEL9K_STATUS_OK=1 
	typeset -g _POWERLEVEL9K_VCS_OUTGOING_CHANGESFORMAT_FOREGROUND='#9AEDFE' 
	typeset -g _POWERLEVEL9K_SHORTEN_STRATEGY='' 
	typeset -g -i _p9k_num_cpus=16 
	typeset -g -i _POWERLEVEL9K_STATUS_ERROR_PIPE=1 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_OK_VICMD_CONTENT_EXPANSION=❮ 
	typeset -g _POWERLEVEL9K_VIRTUALENV_FOREGROUND=242 
	typeset -g -i _POWERLEVEL9K_DOTNET_VERSION_PROJECT_ONLY=1 
	typeset -g -i _POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40 
	typeset -g -A _p9k_battery_states=([CHARGED]=green [CHARGING]=yellow [DISCONNECTED]=7 [LOW]=red) 
	typeset -g _POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES='virtualenv|venv|.venv|env' 
	typeset -g -i _POWERLEVEL9K_DIR_OMIT_FIRST_CHARACTER=0 
	typeset -g _POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER='' 
	typeset -g -i _POWERLEVEL9K_HIDE_BRANCH_ICON=0 
	typeset -g -i _POWERLEVEL9K_PHPENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD_CONTENT_EXPANSION=❮ 
	typeset -g -i _POWERLEVEL9K_SHOW_CHANGESET=0 
	typeset -g _POWERLEVEL9K_CONTEXT_DEFAULT_CONTENT_EXPANSION='' 
	typeset -g -a _POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=() 
	typeset -g -a _POWERLEVEL9K_NODENV_SOURCES=(shell local global) 
	typeset -g _POWERLEVEL9K_NODEENV_LEFT_DELIMITER='[' 
	typeset -g -a _p9k_line_prefix_left=('${_p9k__1l-${${:-${_p9k__bg::=NONE}${_p9k__i::=0}${_p9k__sss::=%f}}+}') 
	typeset -g -i _p9k_timewarrior_dir_mtime=0 
	typeset -g -a _POWERLEVEL9K_DIR_CLASSES=('/etc|/etc/*' ETC ⚙ '~' HOME '' '~/*' HOME_SUBFOLDER '' '*' DEFAULT '') 
	typeset -g _POWERLEVEL9K_TRANSIENT_PROMPT=off 
	typeset -g -a _POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES=('service_account:*' SERVICE_ACCOUNT) 
	typeset -g _POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR='' 
	typeset -g _POWERLEVEL9K_CONTEXT_ROOT_TEMPLATE='%F{#F1F1F0}%n%f%F{242}@%m%f' 
	typeset -g -i _POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW=0 
	typeset -g -A _p9k_asdf_plugins=() 
	typeset -g -a _p9k_line_suffix_left=('%b%k$_p9k__sss%b%k%f${:-" %b%k%f"}}') 
	typeset -g -i _POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g -i _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING=0 
	typeset -g _POWERLEVEL9K_VCS_INCOMING_CHANGES_ICON=:⇣ 
	typeset -g -a _p9k_line_gap_post=() 
	typeset -g -A _p9k_cache=([$'_p9k_color prompt_command_execution_time\C-@BACKGROUND\C-@red']=. [$'_p9k_color prompt_command_execution_time\C-@FOREGROUND\C-@yellow1']='#f3f99d.' [$'_p9k_color prompt_context_DEFAULT\C-@BACKGROUND\C-@0']=. [$'_p9k_color prompt_context_DEFAULT\C-@FOREGROUND\C-@yellow']=003. [$'_p9k_color prompt_context_ROOT\C-@BACKGROUND\C-@0']=. [$'_p9k_color prompt_context_ROOT\C-@FOREGROUND\C-@yellow']=003. [$'_p9k_color prompt_dir_HOME\C-@BACKGROUND\C-@blue']=. [$'_p9k_color prompt_dir_HOME\C-@FOREGROUND\C-@0']='#57c7ff.' [$'_p9k_color prompt_dir_HOME_SUBFOLDER\C-@BACKGROUND\C-@blue']=. [$'_p9k_color prompt_dir_HOME_SUBFOLDER\C-@FOREGROUND\C-@0']='#57c7ff.' [$'_p9k_color prompt_prompt_char_ERROR_VICMD\C-@BACKGROUND\C-@0']=. [$'_p9k_color prompt_prompt_char_ERROR_VICMD\C-@FOREGROUND\C-@196']='#ff5c57.' [$'_p9k_color prompt_prompt_char_ERROR_VIINS\C-@BACKGROUND\C-@0']=. [$'_p9k_color prompt_prompt_char_ERROR_VIINS\C-@FOREGROUND\C-@196']='#ff5c57.' [$'_p9k_color prompt_prompt_char_ERROR_VIVIS\C-@BACKGROUND\C-@0']=. [$'_p9k_color prompt_prompt_char_ERROR_VIVIS\C-@FOREGROUND\C-@196']='#ff5c57.' [$'_p9k_color prompt_prompt_char_OK_VICMD\C-@BACKGROUND\C-@0']=. [$'_p9k_color prompt_prompt_char_OK_VICMD\C-@FOREGROUND\C-@76']='#ff6ac1.' [$'_p9k_color prompt_prompt_char_OK_VIINS\C-@BACKGROUND\C-@0']=. [$'_p9k_color prompt_prompt_char_OK_VIINS\C-@FOREGROUND\C-@76']='#ff6ac1.' [$'_p9k_color prompt_prompt_char_OK_VIVIS\C-@BACKGROUND\C-@0']=. [$'_p9k_color prompt_prompt_char_OK_VIVIS\C-@FOREGROUND\C-@76']='#ff6ac1.' [$'_p9k_color prompt_ruler\C-@BACKGROUND\C-@']=. [$'_p9k_color prompt_ruler\C-@FOREGROUND\C-@']=. [$'_p9k_color prompt_vcs_CLEAN\C-@BACKGROUND\C-@2']=. [$'_p9k_color prompt_vcs_CLEAN\C-@FOREGROUND\C-@0']=242. [$'_p9k_color prompt_vcs_LOADING\C-@BACKGROUND\C-@8']=. [$'_p9k_color prompt_vcs_LOADING\C-@FOREGROUND\C-@0']=242. [$'_p9k_color prompt_vcs_MODIFIED\C-@BACKGROUND\C-@3']=. [$'_p9k_color prompt_vcs_MODIFIED\C-@FOREGROUND\C-@0']=242. [$'_p9k_get_icon \C-@LEFT_SEGMENT_END_SEPARATOR']=' .' [$'_p9k_get_icon \C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon \C-@RULER_CHAR']=─. [$'_p9k_get_icon \C-@VCS_BRANCH_ICON']=. [$'_p9k_get_icon \C-@VCS_STAGED_ICON']=. [$'_p9k_get_icon \C-@VCS_UNSTAGED_ICON']=. [$'_p9k_get_icon prompt_command_execution_time\C-@EXECUTION_TIME_ICON']=. [$'_p9k_get_icon prompt_command_execution_time\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_command_execution_time\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_command_execution_time\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_command_execution_time\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_command_execution_time\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_command_execution_time\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_command_execution_time\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_context_DEFAULT\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_context_DEFAULT\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_context_DEFAULT\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_context_DEFAULT\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_context_DEFAULT\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_context_DEFAULT\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_context_DEFAULT\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_context_ROOT\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_context_ROOT\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_context_ROOT\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_context_ROOT\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_context_ROOT\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_context_ROOT\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_context_ROOT\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_dir_DEFAULT\C-@FOLDER_ICON']=. [$'_p9k_get_icon prompt_dir_ETC\C-@ETC_ICON']=⚙. [$'_p9k_get_icon prompt_dir_HOME\C-@\C-A']=. [$'_p9k_get_icon prompt_dir_HOME\C-@HOME_ICON']=. [$'_p9k_get_icon prompt_dir_HOME\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_dir_HOME\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_dir_HOME\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_dir_HOME\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_dir_HOME\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_dir_HOME\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_dir_HOME\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@\C-A']=. [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@HOME_SUB_ICON']=. [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_dir_HOME_SUBFOLDER\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_empty_line\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_os_icon\C-@LINUX_NIXOS_ICON']=Nix. [$'_p9k_get_icon prompt_prompt_char_ERROR_VICMD\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VICMD\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VICMD\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VICMD\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VICMD\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VICMD\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_prompt_char_ERROR_VICMD\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_prompt_char_ERROR_VIINS\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIINS\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIINS\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIINS\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIINS\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIINS\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_prompt_char_ERROR_VIINS\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_prompt_char_ERROR_VIVIS\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIVIS\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIVIS\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIVIS\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIVIS\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_prompt_char_ERROR_VIVIS\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_prompt_char_ERROR_VIVIS\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_prompt_char_OK_VICMD\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_OK_VICMD\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_OK_VICMD\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_OK_VICMD\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_OK_VICMD\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_prompt_char_OK_VICMD\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_prompt_char_OK_VICMD\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_prompt_char_OK_VIINS\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIINS\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIINS\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIINS\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIINS\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIINS\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_prompt_char_OK_VIINS\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_prompt_char_OK_VIVIS\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIVIS\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIVIS\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIVIS\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIVIS\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_prompt_char_OK_VIVIS\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_prompt_char_OK_VIVIS\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_vcs_CLEAN\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_vcs_CLEAN\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_vcs_CLEAN\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_vcs_CLEAN\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_vcs_CLEAN\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_vcs_CLEAN\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_vcs_CLEAN\C-@VCS_BRANCH_ICON']=. [$'_p9k_get_icon prompt_vcs_CLEAN\C-@VCS_GIT_GITHUB_ICON']=. [$'_p9k_get_icon prompt_vcs_CLEAN\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_vcs_LOADING\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_vcs_LOADING\C-@VCS_BRANCH_ICON']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@VCS_DIRTY_ICON']='*.' [$'_p9k_get_icon prompt_vcs_LOADING\C-@VCS_GIT_GITHUB_ICON']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@VCS_LOADING_ICON']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@VCS_UNSTAGED_ICON']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@VCS_UNTRACKED_ICON']=. [$'_p9k_get_icon prompt_vcs_LOADING\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@LEFT_LEFT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@LEFT_RIGHT_WHITESPACE\C-@ ']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@LEFT_SEGMENT_SEPARATOR']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@LEFT_SUBSEGMENT_SEPARATOR']=' .' [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@VCS_BRANCH_ICON']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@VCS_DIRTY_ICON']='*.' [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@VCS_GIT_GITHUB_ICON']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@VCS_OUTGOING_CHANGES_ICON']=:⇡. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@VCS_UNSTAGED_ICON']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@VCS_UNTRACKED_ICON']=. [$'_p9k_get_icon prompt_vcs_MODIFIED\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@ ']=' .' [$'_p9k_left_prompt_segment\C-@prompt_command_execution_time\C-@red\C-@yellow1\C-@EXECUTION_TIME_ICON\C-@4']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=36}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+38}}${_p9k__n:=39}${_p9k__c::="${P9K_CONTENT}"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lcommand_execution_time+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#f3f99d\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=4}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_context_DEFAULT\C-@0\C-@yellow\C-@\C-@1']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=8}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+10}}${_p9k__n:=11}${_p9k__c::=}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lcontext+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{003\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=1}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_context_ROOT\C-@0\C-@yellow\C-@\C-@1']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=12}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+14}}${_p9k__n:=15}${_p9k__c::="${P9K_CONTENT}"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lcontext+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{003\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=1}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_dir_HOME\C-@blue\C-@0\C-@\C-A\C-@2']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=16}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+18}}${_p9k__n:=19}${_p9k__c::="${P9K_CONTENT}"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1ldir+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#57c7ff\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=2}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_dir_HOME_SUBFOLDER\C-@blue\C-@0\C-@\C-A\C-@2']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=52}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+54}}${_p9k__n:=55}${_p9k__c::="${P9K_CONTENT}"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1ldir+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#57c7ff\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=2}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_prompt_char_ERROR_VICMD\C-@0\C-@196\C-@\C-@6']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=44}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+46}}${_p9k__n:=47}${_p9k__c::="❮"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lprompt_char+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#ff5c57\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=6}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_prompt_char_ERROR_VIINS\C-@0\C-@196\C-@\C-@6']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=40}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+42}}${_p9k__n:=43}${_p9k__c::="❯"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lprompt_char+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#ff5c57\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=6}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_prompt_char_ERROR_VIVIS\C-@0\C-@196\C-@\C-@6']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=48}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+50}}${_p9k__n:=51}${_p9k__c::="❮"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lprompt_char+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#ff5c57\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=6}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_prompt_char_OK_VICMD\C-@0\C-@76\C-@\C-@6']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=24}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+26}}${_p9k__n:=27}${_p9k__c::="❮"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lprompt_char+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#ff6ac1\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=6}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_prompt_char_OK_VIINS\C-@0\C-@76\C-@\C-@6']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=20}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+22}}${_p9k__n:=23}${_p9k__c::="❯"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lprompt_char+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#ff6ac1\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=6}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_prompt_char_OK_VIVIS\C-@0\C-@76\C-@\C-@6']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=28}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+30}}${_p9k__n:=31}${_p9k__c::="❮"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lprompt_char+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{#ff6ac1\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=6}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_vcs_CLEAN\C-@2\C-@0\C-@VCS_GIT_GITHUB_ICON\C-@3']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=60}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+62}}${_p9k__n:=63}${P9K_VISUAL_IDENTIFIER::=}${_p9k__c::="${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lvcs+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{242\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=3}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_vcs_LOADING\C-@8\C-@0\C-@VCS_GIT_GITHUB_ICON\C-@3']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=56}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+58}}${_p9k__n:=59}${P9K_VISUAL_IDENTIFIER::=}${_p9k__c::="${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lvcs+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{242\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=3}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_vcs_LOADING\C-@8\C-@0\C-@VCS_LOADING_ICON\C-@3']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=32}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+34}}${_p9k__n:=35}${P9K_VISUAL_IDENTIFIER::=}${_p9k__c::="${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lvcs+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{242\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=3}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_left_prompt_segment\C-@prompt_vcs_MODIFIED\C-@3\C-@0\C-@VCS_GIT_GITHUB_ICON\C-@3']=$'${_p9k__n::=}${${${_p9k__bg:-0}:#NONE}:-${_p9k__n::=64}}${_p9k__n:=${${(M)${:-x}:#x($_p9k__bg|${_p9k__bg:-0})}:+66}}${_p9k__n:=67}${P9K_VISUAL_IDENTIFIER::=}${_p9k__c::="${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }"}${_p9k__c::=${_p9k__c//\C-M}}${_p9k__e::=${${_p9k__1lvcs+00}:-${${(%):-$_p9k__c%1(l.1.0)}[-1]}0}}}+}${${_p9k__e:#00}:+${${_p9k_t[$_p9k__n]/<_p9k__ss>/$_p9k__ss}/<_p9k__s>/$_p9k__s}${_p9k__c}%b%k%F{242\\}${${:-${_p9k__s::=%F{\\}}${_p9k__ss::= }${_p9k__sss::=%F{\\}}${_p9k__i::=3}${_p9k__bg::=}}+}}\C-@00' [$'_p9k_param \C-@LEFT_SEGMENT_END_SEPARATOR\C-@ ']=' .' [$'_p9k_param \C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param \C-@RULER_CHAR\C-@\\u2500']='\u2500.' [$'_p9k_param \C-@VCS_BRANCH_ICON\C-@\\uE0A0 ']=. [$'_p9k_param \C-@VCS_STAGED_ICON\C-@\\u271A']=. [$'_p9k_param \C-@VCS_UNSTAGED_ICON\C-@\\u25CF']=. [$'_p9k_param prompt_command_execution_time\C-@BACKGROUND\C-@red']=. [$'_p9k_param prompt_command_execution_time\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']='${P9K_CONTENT}.' [$'_p9k_param prompt_command_execution_time\C-@EXECUTION_TIME_ICON']=. [$'_p9k_param prompt_command_execution_time\C-@FOREGROUND\C-@yellow1']='#F3F99D.' [$'_p9k_param prompt_command_execution_time\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_command_execution_time\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_command_execution_time\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_command_execution_time\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_command_execution_time\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_command_execution_time\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_command_execution_time\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_command_execution_time\C-@PREFIX\C-@']=. [$'_p9k_param prompt_command_execution_time\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_command_execution_time\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_command_execution_time\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_command_execution_time\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_command_execution_time\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_context_DEFAULT\C-@BACKGROUND\C-@0']=. [$'_p9k_param prompt_context_DEFAULT\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']=. [$'_p9k_param prompt_context_DEFAULT\C-@FOREGROUND\C-@yellow']=yellow. [$'_p9k_param prompt_context_DEFAULT\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_context_DEFAULT\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_context_DEFAULT\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_context_DEFAULT\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_context_DEFAULT\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_context_DEFAULT\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_context_DEFAULT\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_context_DEFAULT\C-@PREFIX\C-@']=. [$'_p9k_param prompt_context_DEFAULT\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_context_DEFAULT\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_context_DEFAULT\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_context_DEFAULT\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_context_DEFAULT\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_context_ROOT\C-@BACKGROUND\C-@0']=. [$'_p9k_param prompt_context_ROOT\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']='${P9K_CONTENT}.' [$'_p9k_param prompt_context_ROOT\C-@FOREGROUND\C-@yellow']=yellow. [$'_p9k_param prompt_context_ROOT\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_context_ROOT\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_context_ROOT\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_context_ROOT\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_context_ROOT\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_context_ROOT\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_context_ROOT\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_context_ROOT\C-@PREFIX\C-@']=. [$'_p9k_param prompt_context_ROOT\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_context_ROOT\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_context_ROOT\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_context_ROOT\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_context_ROOT\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_dir_DEFAULT\C-@FOLDER_ICON']=. [$'_p9k_param prompt_dir_ETC\C-@ETC_ICON\C-@\\u2699']='\u2699.' [$'_p9k_param prompt_dir_HOME\C-@ANCHOR_BOLD\C-@']=. [$'_p9k_param prompt_dir_HOME\C-@BACKGROUND\C-@blue']=. [$'_p9k_param prompt_dir_HOME\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']='${P9K_CONTENT}.' [$'_p9k_param prompt_dir_HOME\C-@FOREGROUND\C-@0']='#57C7FF.' [$'_p9k_param prompt_dir_HOME\C-@HOME_ICON']=. [$'_p9k_param prompt_dir_HOME\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_dir_HOME\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_dir_HOME\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_dir_HOME\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_dir_HOME\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_dir_HOME\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_dir_HOME\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_dir_HOME\C-@PATH_HIGHLIGHT_BOLD\C-@']=. [$'_p9k_param prompt_dir_HOME\C-@PATH_SEPARATOR\C-@/']=/. [$'_p9k_param prompt_dir_HOME\C-@PREFIX\C-@']=. [$'_p9k_param prompt_dir_HOME\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_dir_HOME\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_dir_HOME\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_dir_HOME\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_dir_HOME\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@ANCHOR_BOLD\C-@']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@BACKGROUND\C-@blue']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']='${P9K_CONTENT}.' [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@FOREGROUND\C-@0']='#57C7FF.' [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@HOME_SUB_ICON']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@PATH_HIGHLIGHT_BOLD\C-@']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@PATH_SEPARATOR\C-@/']=/. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@PREFIX\C-@']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_dir_HOME_SUBFOLDER\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_empty_line\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_os_icon\C-@LINUX_NIXOS_ICON\C-@Nix']=Nix. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@BACKGROUND\C-@0']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']=❮. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@FOREGROUND\C-@196']='#FF5C57.' [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@PREFIX\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_prompt_char_ERROR_VICMD\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@BACKGROUND\C-@0']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']=❯. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@FOREGROUND\C-@196']='#FF5C57.' [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@PREFIX\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_prompt_char_ERROR_VIINS\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@BACKGROUND\C-@0']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']=❮. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@FOREGROUND\C-@196']='#FF5C57.' [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@PREFIX\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_prompt_char_ERROR_VIVIS\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@BACKGROUND\C-@0']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']=❮. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@FOREGROUND\C-@76']='#FF6AC1.' [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@PREFIX\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_prompt_char_OK_VICMD\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@BACKGROUND\C-@0']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']=❯. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@FOREGROUND\C-@76']='#FF6AC1.' [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@PREFIX\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_prompt_char_OK_VIINS\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@BACKGROUND\C-@0']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']=❮. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@FOREGROUND\C-@76']='#FF6AC1.' [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@PREFIX\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_prompt_char_OK_VIVIS\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_ruler\C-@BACKGROUND\C-@']=. [$'_p9k_param prompt_ruler\C-@FOREGROUND\C-@']=. [$'_p9k_param prompt_vcs_CLEAN\C-@BACKGROUND\C-@2']=. [$'_p9k_param prompt_vcs_CLEAN\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }.' [$'_p9k_param prompt_vcs_CLEAN\C-@CONTENT_EXPANSION\C-@x']='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }.' [$'_p9k_param prompt_vcs_CLEAN\C-@FOREGROUND\C-@0']=242. [$'_p9k_param prompt_vcs_CLEAN\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_vcs_CLEAN\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_vcs_CLEAN\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_vcs_CLEAN\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_vcs_CLEAN\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_vcs_CLEAN\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_vcs_CLEAN\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_vcs_CLEAN\C-@PREFIX\C-@']=. [$'_p9k_param prompt_vcs_CLEAN\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_vcs_CLEAN\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_vcs_CLEAN\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_vcs_CLEAN\C-@VCS_BRANCH_ICON\C-@\\uE0A0 ']=. [$'_p9k_param prompt_vcs_CLEAN\C-@VCS_GIT_GITHUB_ICON']=. [$'_p9k_param prompt_vcs_CLEAN\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_vcs_CLEAN\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_vcs_CONFLICTED\C-@CONTENT_EXPANSION\C-@x']='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }.' [$'_p9k_param prompt_vcs_LOADING\C-@BACKGROUND\C-@8']=. [$'_p9k_param prompt_vcs_LOADING\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }.' [$'_p9k_param prompt_vcs_LOADING\C-@CONTENT_EXPANSION\C-@x']='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }.' [$'_p9k_param prompt_vcs_LOADING\C-@FOREGROUND\C-@0']=242. [$'_p9k_param prompt_vcs_LOADING\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_vcs_LOADING\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_vcs_LOADING\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_vcs_LOADING\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_vcs_LOADING\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_vcs_LOADING\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_vcs_LOADING\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_vcs_LOADING\C-@PREFIX\C-@']=. [$'_p9k_param prompt_vcs_LOADING\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_vcs_LOADING\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_vcs_LOADING\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_vcs_LOADING\C-@VCS_BRANCH_ICON\C-@\\uE0A0 ']=. [$'_p9k_param prompt_vcs_LOADING\C-@VCS_DIRTY_ICON\C-@\C-A']='*.' [$'_p9k_param prompt_vcs_LOADING\C-@VCS_GIT_GITHUB_ICON']=. [$'_p9k_param prompt_vcs_LOADING\C-@VCS_LOADING_ICON']=. [$'_p9k_param prompt_vcs_LOADING\C-@VCS_UNSTAGED_ICON\C-@\\u25CF']=. [$'_p9k_param prompt_vcs_LOADING\C-@VCS_UNTRACKED_ICON\C-@?']=. [$'_p9k_param prompt_vcs_LOADING\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_vcs_LOADING\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_vcs_MODIFIED\C-@BACKGROUND\C-@3']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@CONTENT_EXPANSION\C-@${P9K_CONTENT}']='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }.' [$'_p9k_param prompt_vcs_MODIFIED\C-@CONTENT_EXPANSION\C-@x']='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }.' [$'_p9k_param prompt_vcs_MODIFIED\C-@FOREGROUND\C-@0']=242. [$'_p9k_param prompt_vcs_MODIFIED\C-@ICON_BEFORE_CONTENT\C-@']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@LEFT_LEFT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_vcs_MODIFIED\C-@LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL\C-@\C-A']=$'\C-A.' [$'_p9k_param prompt_vcs_MODIFIED\C-@LEFT_RIGHT_WHITESPACE\C-@\C-A ']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@LEFT_SEGMENT_SEPARATOR\C-@\\uE0B0']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@LEFT_SUBSEGMENT_SEPARATOR\C-@\\uE0B1']=' .' [$'_p9k_param prompt_vcs_MODIFIED\C-@PREFIX\C-@']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@SELF_JOINED\C-@false']=false. [$'_p9k_param prompt_vcs_MODIFIED\C-@SHOW_ON_UPGLOB\C-@']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@SUFFIX\C-@']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@VCS_BRANCH_ICON\C-@\\uE0A0 ']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@VCS_DIRTY_ICON\C-@\C-A']='*.' [$'_p9k_param prompt_vcs_MODIFIED\C-@VCS_GIT_GITHUB_ICON']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@VCS_OUTGOING_CHANGES_ICON\C-@\\u2191']=:⇡. [$'_p9k_param prompt_vcs_MODIFIED\C-@VCS_UNSTAGED_ICON\C-@\\u25CF']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@VCS_UNTRACKED_ICON\C-@?']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@VISUAL_IDENTIFIER_EXPANSION\C-@${P9K_VISUAL_IDENTIFIER}']=. [$'_p9k_param prompt_vcs_MODIFIED\C-@WHITESPACE_BETWEEN_LEFT_SEGMENTS\C-@\C-A ']=$'\C-A .' [$'_p9k_param prompt_vcs_UNTRACKED\C-@CONTENT_EXPANSION\C-@x']='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }.' [$'_p9k_vcs_style CLEAN\C-@BRANCH']='%b%k%F{242}.' [$'_p9k_vcs_style LOADING\C-@BRANCH']='%b%k%F{242}.' [$'_p9k_vcs_style LOADING\C-@DIRTY']='%b%k%F{242}.' [$'_p9k_vcs_style LOADING\C-@UNSTAGED']='%b%k%F{242}.' [$'_p9k_vcs_style LOADING\C-@UNTRACKED']='%b%k%F{242}.' [$'_p9k_vcs_style MODIFIED\C-@BRANCH']='%b%k%F{242}.' [$'_p9k_vcs_style MODIFIED\C-@DIRTY']='%b%k%F{242}.' [$'_p9k_vcs_style MODIFIED\C-@OUTGOING_CHANGES']='%b%k%F{#9aedfe}.' [$'_p9k_vcs_style MODIFIED\C-@UNSTAGED']='%b%k%F{242}.' [$'_p9k_vcs_style MODIFIED\C-@UNTRACKED']='%b%k%F{242}.') 
	typeset -g -F _p9k_taskwarrior_next_due=0.0000000000 
	typeset -g _p9k_preinit=$'function _p9k_preinit() {\n    (( 1 )) || { unfunction _p9k_preinit; return 1 }\n    [[ $ZSH_VERSION == 5.9 ]]                      || return\n    [[ -r /nix/store/gnwfrf0rn9xx5h5gj1sbhlm8w76iqv2n-powerlevel10k-1.20.15/share/zsh/themes/powerlevel10k/gitstatus/gitstatus.plugin.zsh ]]             || return\n    builtin source /nix/store/gnwfrf0rn9xx5h5gj1sbhlm8w76iqv2n-powerlevel10k-1.20.15/share/zsh/themes/powerlevel10k/gitstatus/gitstatus.plugin.zsh _p9k_ || return\n    GITSTATUS_AUTO_INSTALL=\'\'               GITSTATUS_DAEMON=/nix/store/13mfs3cqbya42wy55s88275g8m4b4z5y-gitstatus-1.5.5/bin/gitstatusd                         GITSTATUS_CACHE_DIR=\'\'                   GITSTATUS_NUM_THREADS=\'\'               GITSTATUS_LOG_LEVEL=\'\'                   GITSTATUS_ENABLE_LOGGING=\'\'           gitstatus_start_p9k_                                              -s 1                            -u 1                          -d 1                         -c 1                        -m -1                                 -a POWERLEVEL9K\n  }' 
	typeset -g -a _p9k_asdf_meta_non_files=() 
	typeset -g -i _p9k_empty_line_idx=4 
	typeset -g _POWERLEVEL9K_VISUAL_IDENTIFIER_EXPANSION='' 
	typeset -g -i _POWERLEVEL9K_CHRUBY_SHOW_ENGINE=1 
	typeset -g -i _POWERLEVEL9K_PLENV_SHOW_SYSTEM=1 
	typeset -g -i _POWERLEVEL9K_VCS_UNTRACKED_MAX_NUM=1 
	typeset -g _p9k_os=Linux 
	typeset -g _POWERLEVEL9K_VCS_UNTRACKED_ICON='' 
	typeset -g -i _POWERLEVEL9K_JAVA_VERSION_PROJECT_ONLY=0 
	typeset -g _POWERLEVEL9K_VIRTUALENV_LEFT_DELIMITER='' 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_OK_VIVIS_FOREGROUND='#FF6AC1' 
	typeset -g -a _POWERLEVEL9K_BATTERY_CHARGED_LEVEL_BACKGROUND=() 
	typeset -g _p9k_prompt_prefix_left='${(e)_p9k_t[7]}' 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION=❯ 
	typeset -g -i _POWERLEVEL9K_TERRAFORM_SHOW_DEFAULT=0 
	typeset -g -a _POWERLEVEL9K_AWS_CLASSES=() 
	typeset -g -a _POWERLEVEL9K_VCS_SVN_HOOKS=(vcs-detect-changes svn-detect-changes) 
	typeset -g -i _POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1 
	typeset -g -i _p9k_reset_on_line_finish=0 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION=❯ 
	typeset -g -i _POWERLEVEL9K_VCS_CONFLICTED_STATE=0 
	typeset -g _p9k_prompt_suffix_left=$'${${COLUMNS::=$_p9k__clm}+}%{\C-[]133;B\C-G%}' 
	typeset -g -F _POWERLEVEL9K_GCLOUD_REFRESH_PROJECT_NAME_SECONDS=60.0000000000 
	typeset -g -i _POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE_ALWAYS=0 
	typeset -g _POWERLEVEL9K_VCS_LOADING_TEXT='' 
	typeset -g -a _POWERLEVEL9K_BATTERY_STAGES=() 
	typeset -g -A _p9k_display_k=([-1]=5 [-1/gap]=15 [-1/left]=11 [-1/left/command_execution_time]=23 [-1/left/context]=17 [-1/left/dir]=19 [-1/left/prompt_char]=27 [-1/left/vcs]=21 [-1/left/virtualenv]=25 [-1/left_frame]=7 [-1/right]=13 [-1/right_frame]=9 [1]=5 [1/gap]=15 [1/left]=11 [1/left/command_execution_time]=23 [1/left/context]=17 [1/left/dir]=19 [1/left/prompt_char]=27 [1/left/vcs]=21 [1/left/virtualenv]=25 [1/left_frame]=7 [1/right]=13 [1/right_frame]=9 [empty_line]=1 [ruler]=3) 
	typeset -g -a _POWERLEVEL9K_BATTERY_LOW_STAGES=() 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD_FOREGROUND='#FF5C57' 
	typeset -g _POWERLEVEL9K_VPN_IP_INTERFACE='' 
	typeset -g _p9k_timewarrior_dir='' 
	typeset -g -i _POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING=0 
	typeset -g _p9k_gap_pre='${(e)_p9k_t[6]}' 
	typeset -g _p9k_taskwarrior_meta_sig='' 
	typeset -g -i _POWERLEVEL9K_RPROMPT_ON_NEWLINE=0 
	typeset -g -i _POWERLEVEL9K_STATUS_OK_IN_NON_VERBOSE=0 
	typeset -g _p9k_uname=Linux 
	typeset -g _POWERLEVEL9K_CONFIG_FILE=/home/zak/.config/zsh/.p10k.zsh 
	typeset -g -F _POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=50.0000000000 
	typeset -g -i _POWERLEVEL9K_BATTERY_DISCONNECTED_HIDE_ABOVE_THRESHOLD=999 
	typeset -g -i _POWERLEVEL9K_DISABLE_RPROMPT=0 
	typeset -g _p9k_gcloud_configuration='' 
	typeset -g -a _POWERLEVEL9K_VCS_BACKENDS=(git) 
	typeset -g _POWERLEVEL9K_COLOR_SCHEME=dark 
	typeset -g -a _POWERLEVEL9K_HASKELL_STACK_SOURCES=(shell local) 
	typeset -g -i _POWERLEVEL9K_RVM_SHOW_PREFIX=0 
	typeset -g -i _POWERLEVEL9K_JAVA_VERSION_FULL=1 
	typeset -g -A icons=([ANDROID_ICON]=And [APPLE_ICON]=OSX [ARCH_ICON]=arch [AWS_EB_ICON]='\U1F331' [AWS_ICON]=AWS [AZURE_ICON]='\u2601' [BACKGROUND_JOBS_ICON]='\u2699' [BATTERY_ICON]='\U1F50B' [CARRIAGE_RETURN_ICON]='\u21B5' [CHEZMOI_ICON]=Chez [DATE_ICON]='' [DIRENV_ICON]='\u25BC' [DISK_ICON]=hdd [DOTNET_CORE_ICON]=.NET [DOTNET_ICON]=.NET [DROPBOX_ICON]=Dropbox [ELIXIR_ICON]=elixir [ERLANG_ICON]=erl [ETC_ICON]='\u2699' [EXECUTION_TIME_ICON]='' [FAIL_ICON]='\u2718' [FLUTTER_ICON]=F [FOLDER_ICON]='' [FREEBSD_ICON]=BSD [GCLOUD_ICON]=G [GOLANG_ICON]=Go [GO_ICON]=Go [HASKELL_ICON]=hs [HISTORY_ICON]=hist [HOME_ICON]='' [HOME_SUB_ICON]='' [JAVA_ICON]='\U2615' [JULIA_ICON]=jl [KUBERNETES_ICON]='\U2388' [LARAVEL_ICON]='' [LEFT_SEGMENT_END_SEPARATOR]=' ' [LEFT_SEGMENT_SEPARATOR]='\uE0B0' [LEFT_SUBSEGMENT_SEPARATOR]='\uE0B1' [LF_ICON]=lf [LINUX_ALMALINUX_ICON]=Alma [LINUX_ALPINE_ICON]=Alp [LINUX_AMZN_ICON]=Amzn [LINUX_AOSC_ICON]=Aos [LINUX_ARCH_ICON]=Arc [LINUX_ARTIX_ICON]=Art [LINUX_CENTOS_ICON]=Cen [LINUX_COREOS_ICON]=Cor [LINUX_DEBIAN_ICON]=Deb [LINUX_DEVUAN_ICON]=Dev [LINUX_ELEMENTARY_ICON]=Elm [LINUX_ENDEAVOUROS_ICON]=Edv [LINUX_FEDORA_ICON]=Fed [LINUX_GENTOO_ICON]=Gen [LINUX_GUIX_ICON]=Guix [LINUX_ICON]=Lx [LINUX_KALI_ICON]=Kal [LINUX_MAGEIA_ICON]=Mag [LINUX_MANJARO_ICON]=Man [LINUX_MINT_ICON]=LMi [LINUX_NEON_ICON]=Neon [LINUX_NIXOS_ICON]=Nix [LINUX_OPENSUSE_ICON]=OSu [LINUX_RASPBIAN_ICON]=RPi [LINUX_RHEL_ICON]=RH [LINUX_ROCKY_ICON]=Roc [LINUX_SABAYON_ICON]=Sab [LINUX_SLACKWARE_ICON]=Sla [LINUX_UBUNTU_ICON]=Ubu [LINUX_VOID_ICON]=Vo [LOAD_ICON]=L [LOCK_ICON]='\UE0A2' [LUA_ICON]=lua [MIDNIGHT_COMMANDER_ICON]=mc [MULTILINE_FIRST_PROMPT_PREFIX]='\u256D\U2500' [MULTILINE_LAST_PROMPT_PREFIX]='\u2570\U2500 ' [MULTILINE_NEWLINE_PROMPT_PREFIX]='\u251C\U2500' [NETWORK_ICON]=IP [NIX_SHELL_ICON]=nix [NNN_ICON]=nnn [NODEJS_ICON]=Node [NODE_ICON]=Node [NORDVPN_ICON]='\UE0A2' [OK_ICON]='\u2714' [PACKAGE_ICON]=pkg [PERL_ICON]=perl [PHP_ICON]=php [POSTGRES_ICON]=postgres [PROXY_ICON]='\u2194' [PUBLIC_IP_ICON]=IP [PYTHON_ICON]=Py [RAM_ICON]=RAM [RANGER_ICON]='\u2B50' [RIGHT_SEGMENT_SEPARATOR]='\uE0B2' [RIGHT_SUBSEGMENT_SEPARATOR]='\uE0B3' [ROOT_ICON]='\u26A1' [RUBY_ICON]=Ruby [RULER_CHAR]='\u2500' [RUST_ICON]=R [SCALA_ICON]=scala [SERVER_ICON]='' [SSH_ICON]=ssh [SUDO_ICON]='' [SUNOS_ICON]=Sun [SWAP_ICON]=SWP [SWIFT_ICON]=Swift [SYMFONY_ICON]=SF [TASKWARRIOR_ICON]=task [TERRAFORM_ICON]=tf [TEST_ICON]='' [TIMEWARRIOR_ICON]=tw [TIME_ICON]='' [TODO_ICON]='\u2206' [TOOLBOX_ICON]='\u2B22' [VCS_BOOKMARK_ICON]='\u263F' [VCS_BRANCH_ICON]='\uE0A0 ' [VCS_COMMIT_ICON]='' [VCS_GIT_ARCHLINUX_ICON]='' [VCS_GIT_AZURE_ICON]='' [VCS_GIT_BITBUCKET_ICON]='' [VCS_GIT_CODEBERG_ICON]='' [VCS_GIT_DEBIAN_ICON]='' [VCS_GIT_FREEBSD_ICON]='' [VCS_GIT_FREEDESKTOP_ICON]='' [VCS_GIT_GITEA_ICON]='' [VCS_GIT_GITHUB_ICON]='' [VCS_GIT_GITLAB_ICON]='' [VCS_GIT_GNOME_ICON]='' [VCS_GIT_GNU_ICON]='' [VCS_GIT_ICON]='' [VCS_GIT_KDE_ICON]='' [VCS_GIT_LINUX_ICON]='' [VCS_GIT_SOURCEHUT_ICON]='' [VCS_HG_ICON]='' [VCS_INCOMING_CHANGES_ICON]='\u2193' [VCS_LOADING_ICON]='' [VCS_OUTGOING_CHANGES_ICON]='\u2191' [VCS_REMOTE_BRANCH_ICON]='\u2192' [VCS_STAGED_ICON]='\u271A' [VCS_STASH_ICON]='\u235F' [VCS_SVN_ICON]='' [VCS_TAG_ICON]='' [VCS_UNSTAGED_ICON]='\u25CF' [VCS_UNTRACKED_ICON]='?' [VIM_ICON]=vim [VPN_ICON]=vpn [WIFI_ICON]=WiFi [WINDOWS_ICON]=WIN [XPLR_ICON]=xplr [YAZI_ICON]='\u2B50') 
	typeset -g -i _POWERLEVEL9K_STATUS_OK_PIPE=1 
	typeset -g _POWERLEVEL9K_LEFT_LEFT_WHITESPACE='' 
	typeset -g -i _POWERLEVEL9K_VCS_UNSTAGED_MAX_NUM=1 
	typeset -g -i _POWERLEVEL9K_STATUS_CROSS=0 
	typeset -g _POWERLEVEL9K_VCS_OUTGOING_CHANGES_ICON=:⇡ 
	typeset -g _POWERLEVEL9K_VCS_FOREGROUND=242 
	typeset -g _p9k_taskwarrior_data_dir='' 
	typeset -g -i _POWERLEVEL9K_STATUS_VERBOSE=1 
	typeset -g -a _POWERLEVEL9K_BATTERY_DISCONNECTED_LEVEL_FOREGROUND=() 
	typeset -g _POWERLEVEL9K_VCS_STAGED_ICON='' 
	typeset -g -a _POWERLEVEL9K_RBENV_SOURCES=(shell local global) 
	typeset -g -a _POWERLEVEL9K_BATTERY_LOW_LEVEL_FOREGROUND=() 
	typeset -g _POWERLEVEL9K_BACKGROUND='' 
	typeset -g -a _POWERLEVEL9K_VCS_GIT_REMOTE_ICONS=('(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)archlinux.org)(|[/:?#]*)' VCS_GIT_ARCHLINUX_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)dev.azure.com|visualstudio.com)(|[/:?#]*)' VCS_GIT_AZURE_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)bitbucket.org)(|[/:?#]*)' VCS_GIT_BITBUCKET_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)codeberg.org)(|[/:?#]*)' VCS_GIT_CODEBERG_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)debian.org)(|[/:?#]*)' VCS_GIT_DEBIAN_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)freebsd.org)(|[/:?#]*)' VCS_GIT_FREEBSD_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)freedesktop.org)(|[/:?#]*)' VCS_GIT_FREEDESKTOP_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)gitea.com|gitea.io)(|[/:?#]*)' VCS_GIT_GITEA_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)github.com)(|[/:?#]*)' VCS_GIT_GITHUB_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)gitlab.com)(|[/:?#]*)' VCS_GIT_GITLAB_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)gnome.org)(|[/:?#]*)' VCS_GIT_GNOME_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)gnu.org)(|[/:?#]*)' VCS_GIT_GNU_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)kde.org)(|[/:?#]*)' VCS_GIT_KDE_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)kernel.org)(|[/:?#]*)' VCS_GIT_LINUX_ICON '(|[A-Za-z0-9][A-Za-z0-9+.-]#://)(|[^:/?#]#[.@])((#i)sr.ht)(|[/:?#]*)' VCS_GIT_SOURCEHUT_ICON '*' VCS_GIT_ICON) 
	typeset -g -i _POWERLEVEL9K_EXPERIMENTAL_TIME_REALTIME=0 
	typeset -g _p9k_taskwarrior_data_sig='' 
	typeset -g _POWERLEVEL9K_CONTEXT_SUDO_CONTENT_EXPANSION='' 
	typeset -g -a _p9k_left_join=(1 2 3 4 5 6) 
	typeset -g _POWERLEVEL9K_VCS_ACTIONFORMAT_FOREGROUND=1 
	typeset -g -a _POWERLEVEL9K_SCALAENV_SOURCES=(shell local global) 
	typeset -g -i _POWERLEVEL9K_DIR_HYPERLINK=0 
	typeset -g _POWERLEVEL9K_HOME_FOLDER_ABBREVIATION='~' 
	typeset -g -a _POWERLEVEL9K_BATTERY_LEVEL_BACKGROUND=() 
	typeset -g -i _POWERLEVEL9K_BATTERY_VERBOSE=1 
	typeset -g -i _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=0 
	typeset -g -a _POWERLEVEL9K_BATTERY_CHARGING_LEVEL_BACKGROUND=() 
	typeset -g -a _POWERLEVEL9K_BATTERY_DISCONNECTED_STAGES=() 
	typeset -g -A _p9k_git_slow=([/home/zak/work/hbc/boost/act]=1) 
	typeset -g _POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR='' 
	typeset -g -i _POWERLEVEL9K_STATUS_ERROR=1 
	typeset -g -i _POWERLEVEL9K_DISABLE_HOT_RELOAD=1 
	typeset -g -i _POWERLEVEL9K_VCS_COMMITS_AHEAD_MAX_NUM=1 
	typeset -g -a _p9k_line_never_empty_right=(0) 
	typeset -g -a _p9k_line_segments_left=($'context\C-@dir\C-@vcs\C-@command_execution_time\C-@virtualenv\C-@prompt_char') 
	typeset -g -i _POWERLEVEL9K_VCS_STAGED_MAX_NUM=1 
	typeset -g -i _POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=0 
	typeset -g -i _POWERLEVEL9K_CHANGESET_HASH_LENGTH=8 
	typeset -g -a _POWERLEVEL9K_PLENV_SOURCES=(shell local global) 
	typeset -g -i _POWERLEVEL9K_RVM_SHOW_GEMSET=0 
	typeset -g -i _p9k_ruler_idx=5 
	typeset -g -i _POWERLEVEL9K_PHP_VERSION_PROJECT_ONLY=0 
	typeset -g -a _p9k_line_prefix_right=('${_p9k__1r-${${:-${_p9k__bg::=NONE}${_p9k__i::=0}${_p9k__sss::=}}+}') 
	typeset -g _POWERLEVEL9K_CHRUBY_SHOW_ENGINE_PATTERN='*' 
	typeset -g _POWERLEVEL9K_VCS_SHORTEN_DELIMITER=… 
	typeset -g -i _POWERLEVEL9K_CHRUBY_SHOW_VERSION=1 
	typeset -g -i _POWERLEVEL9K_RUST_VERSION_PROJECT_ONLY=1 
	typeset -g -a _POWERLEVEL9K_AZURE_CLASSES=() 
	typeset -g _POWERLEVEL9K_TIME_FOREGROUND=242 
	typeset -g _POWERLEVEL9K_VCS_BRANCH_ICON='' 
	typeset -g -a _POWERLEVEL9K_ASDF_SOURCES=(shell local global) 
	typeset -g -i _POWERLEVEL9K_PLENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g -i _POWERLEVEL9K_NVM_PROMPT_ALWAYS_SHOW=0 
	typeset -g -i _POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g -i _POWERLEVEL9K_TERM_SHELL_INTEGRATION=1 
	typeset -g _p9k_vcs_side=left 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND='#FF5C57' 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_OK_VIVIS_CONTENT_EXPANSION=❮ 
	typeset -g -i _p9k_vcs_index=3 
	typeset -g _POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=' ' 
	typeset -g -a _POWERLEVEL9K_BATTERY_CHARGED_STAGES=() 
	typeset -g -i _POWERLEVEL9K_NODEENV_SHOW_NODE_VERSION=1 
	typeset -g _POWERLEVEL9K_VCS_COMMIT_ICON=@ 
	typeset -g -i _POWERLEVEL9K_VCS_CONFLICTED_MAX_NUM=1 
	typeset -g -i _POWERLEVEL9K_VCS_HIDE_TAGS=0 
	typeset -g -i _POWERLEVEL9K_PROMPT_ADD_NEWLINE=0 
	typeset -g _p9k_color1=0 
	typeset -g _p9k_gcloud_project_name='' 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_OK_VICMD_FOREGROUND='#FF6AC1' 
	typeset -g -a _POWERLEVEL9K_PHPENV_SOURCES=(shell local global) 
	typeset -g _p9k_color2=7 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_ERROR_VIVIS_CONTENT_EXPANSION=❮ 
	typeset -g _POWERLEVEL9K_RIGHT_RIGHT_WHITESPACE='' 
	typeset -g _POWERLEVEL9K_VCS_INCOMING_CHANGESFORMAT_FOREGROUND='#9AEDFE' 
	typeset -g -i _POWERLEVEL9K_ANACONDA_SHOW_PYTHON_VERSION=1 
	typeset -g _POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}' 
	typeset -g _POWERLEVEL9K_RIGHT_LEFT_WHITESPACE='' 
	typeset -g _p9k_nix_shell_cond='${IN_NIX_SHELL:#0}' 
	typeset -g -i _POWERLEVEL9K_VPN_IP_SHOW_ALL=0 
	typeset -g -A _p9k_dumped_instant_prompt_sigs=([/home/zak/work/hbc/boost/act:0:%]=1) 
	typeset -g -i _POWERLEVEL9K_GO_VERSION_PROJECT_ONLY=1 
	typeset -g -i _POWERLEVEL9K_STATUS_ERROR_SIGNAL=1 
	typeset -g -i _POWERLEVEL9K_BATTERY_LOW_THRESHOLD=10 
	typeset -g -a _p9k_taskwarrior_data_non_files=() 
	typeset -g -i _POWERLEVEL9K_SCALAENV_PROMPT_ALWAYS_SHOW=0 
	typeset -g -F _POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=5.0000000000 
	typeset -g -a _POWERLEVEL9K_VCS_HG_HOOKS=(vcs-detect-changes) 
	typeset -g -i _POWERLEVEL9K_BATTERY_LOW_HIDE_ABOVE_THRESHOLD=999 
	typeset -g -i _POWERLEVEL9K_NODENV_SHOW_SYSTEM=1 
	typeset -g -a _POWERLEVEL9K_DIR_PACKAGE_FILES=(package.json composer.json) 
	typeset -g -i _POWERLEVEL9K_TODO_HIDE_ZERO_FILTERED=0 
	typeset -g -i _POWERLEVEL9K_JENV_SHOW_SYSTEM=1 
	typeset -g -a _POWERLEVEL9K_BATTERY_CHARGING_STAGES=() 
	typeset -g _POWERLEVEL9K_VCS_CONTENT_EXPANSION='${${${P9K_CONTENT/⇣* :⇡/⇣⇡}// }//:/ }' 
	typeset -g -a _POWERLEVEL9K_PUBLIC_IP_METHODS=(dig curl wget) 
	typeset -g -i _POWERLEVEL9K_SHOW_RULER=0 
	typeset -g -i _POWERLEVEL9K_PHPENV_SHOW_SYSTEM=1 
	typeset -g -i _POWERLEVEL9K_BATTERY_CHARGED_HIDE_ABOVE_THRESHOLD=999 
	typeset -g -A _p9k_taskwarrior_counters=() 
	typeset -g -i _POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL=90 
	typeset -g _POWERLEVEL9K_VI_INSERT_MODE_STRING=INSERT 
	typeset -g -i _POWERLEVEL9K_BATTERY_CHARGING_HIDE_ABOVE_THRESHOLD=999 
	typeset -g _POWERLEVEL9K_NODEENV_RIGHT_DELIMITER=']' 
	typeset -g _POWERLEVEL9K_VCS_DIRTY_ICON='*' 
	typeset -g -i _POWERLEVEL9K_MAX_CACHE_SIZE=10000 
	typeset -g _p9k_os_icon=Nix 
	typeset -g -i _p9k_vcs_line_index=1 
	typeset -g _POWERLEVEL9K_USER_TEMPLATE=%n 
	typeset -g -F _POWERLEVEL9K_GITSTATUS_INIT_TIMEOUT_SEC=10.0000000000 
	typeset -g -a _p9k_taskwarrior_meta_non_files=() 
	typeset -g _POWERLEVEL9K_ANACONDA_LEFT_DELIMITER='(' 
	typeset -g _POWERLEVEL9K_PUBLIC_IP_NONE='' 
	typeset -g -a _p9k_show_on_command=() 
	typeset -g -a _POWERLEVEL9K_BATTERY_CHARGED_LEVEL_FOREGROUND=() 
	typeset -g -a _POWERLEVEL9K_KUBECONTEXT_SHORTEN=() 
	typeset -g _POWERLEVEL9K_DATE_FORMAT='%D{%d.%m.%y}' 
	typeset -g -a _POWERLEVEL9K_HOOK_WIDGETS=() 
	typeset -g -i _POWERLEVEL9K_RBENV_SHOW_SYSTEM=1 
	typeset -g -i _POWERLEVEL9K_ALWAYS_SHOW_CONTEXT=0 
	typeset -g -F _POWERLEVEL9K_LOAD_CRITICAL_PCT=70.0000000000 
	typeset -g -i _POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL=95 
	typeset -g _POWERLEVEL9K_CONTEXT_TEMPLATE='%F{242}%n@%m%f' 
	typeset -g _POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV=true 
	typeset -g -i _POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=1 
	typeset -g -a _p9k_t=($'\n' $'%{\n%}' '' $'\n' '%b%k%f${(pl.${$((_p9k__clm-_p9k__ind))/#-*/0}..─.)}%k%f${_p9k_t[$((1+!_p9k__ind))]}' '${${:-${_p9k__x::=0}${_p9k__y::=1024}${_p9k__p::=$_p9k__lprompt$_p9k__rprompt}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$(((_p9k__x+_p9k__y)/2))}${_p9k__xy::=${${(%):-$_p9k__p%$_p9k__m(l./$_p9k__m;$_p9k__y./$_p9k__x;$_p9k__m)}##*/}}${_p9k__x::=${_p9k__xy%;*}}${_p9k__y::=${_p9k__xy#*;}}${_p9k__m::=$((_p9k__clm-_p9k__x-_p9k__ind-1))}}+}' $'${${_p9k__clm::=$COLUMNS}+}${${COLUMNS::=1024}+}${${_p9k__keymap::=${KEYMAP:-$_p9k__keymap}}+}%b%k%f${${_p9k__ind::=${${ZLE_RPROMPT_INDENT:-1}/#-*/0}}+}%{\C-[]133;A\C-G%}${_p9k_t[${_p9k__empty_line_i:-4}]}%{${_p9k__ipe-${_p9k_t[${_p9k__ruler_i:-1}]:+\n\C-[M}}%}${(e)_p9k_t[${_p9k__ruler_i:-5}]}' '%b%k%F{003}' '%b%k%F{003}' '%b%k<_p9k__ss>%b%k%F{003}' '%b%k<_p9k__s>%b%k%F{003}' '%b%k%F{003}' '%b%k%F{003}' '%b%k<_p9k__ss>%b%k%F{003}' '%b%k<_p9k__s>%b%k%F{003}' '%b%k%F{#57c7ff}' '%b%k%F{#57c7ff}' '%b%k<_p9k__ss>%b%k%F{#57c7ff}' '%b%k<_p9k__s>%b%k%F{#57c7ff}' '%b%k%F{#ff6ac1}' '%b%k%F{#ff6ac1}' '%b%k<_p9k__ss>%b%k%F{#ff6ac1}' '%b%k<_p9k__s>%b%k%F{#ff6ac1}' '%b%k%F{#ff6ac1}' '%b%k%F{#ff6ac1}' '%b%k<_p9k__ss>%b%k%F{#ff6ac1}' '%b%k<_p9k__s>%b%k%F{#ff6ac1}' '%b%k%F{#ff6ac1}' '%b%k%F{#ff6ac1}' '%b%k<_p9k__ss>%b%k%F{#ff6ac1}' '%b%k<_p9k__s>%b%k%F{#ff6ac1}' '%b%k%F{242}' '%b%k%F{242}' '%b%k<_p9k__ss>%b%k%F{242}' '%b%k<_p9k__s>%b%k%F{242}' '%b%k%F{#f3f99d}' '%b%k%F{#f3f99d}' '%b%k<_p9k__ss>%b%k%F{#f3f99d}' '%b%k<_p9k__s>%b%k%F{#f3f99d}' '%b%k%F{#ff5c57}' '%b%k%F{#ff5c57}' '%b%k<_p9k__ss>%b%k%F{#ff5c57}' '%b%k<_p9k__s>%b%k%F{#ff5c57}' '%b%k%F{#ff5c57}' '%b%k%F{#ff5c57}' '%b%k<_p9k__ss>%b%k%F{#ff5c57}' '%b%k<_p9k__s>%b%k%F{#ff5c57}' '%b%k%F{#ff5c57}' '%b%k%F{#ff5c57}' '%b%k<_p9k__ss>%b%k%F{#ff5c57}' '%b%k<_p9k__s>%b%k%F{#ff5c57}' '%b%k%F{#57c7ff}' '%b%k%F{#57c7ff}' '%b%k<_p9k__ss>%b%k%F{#57c7ff}' '%b%k<_p9k__s>%b%k%F{#57c7ff}' '%b%k%F{242}' '%b%k%F{242}' '%b%k<_p9k__ss>%b%k%F{242}' '%b%k<_p9k__s>%b%k%F{242}' '%b%k%F{242}' '%b%k%F{242}' '%b%k<_p9k__ss>%b%k%F{242}' '%b%k<_p9k__s>%b%k%F{242}' '%b%k%F{242}' '%b%k%F{242}' '%b%k<_p9k__ss>%b%k%F{242}' '%b%k<_p9k__s>%b%k%F{242}') 
	typeset -g -i _POWERLEVEL9K_DIR_SHOW_WRITABLE=0 
	typeset -g -F _POWERLEVEL9K_PUBLIC_IP_TIMEOUT=300.0000000000 
	typeset -g -i _POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=0 
	typeset -g -a _p9k_line_suffix_right=('$_p9k__sss%b%k%f}') 
	typeset -g _p9k_prompt_prefix_right='${_p9k__1-${${_p9k__clm::=$COLUMNS}+}${${COLUMNS::=1024}+}' 
	typeset -g _POWERLEVEL9K_VCS_UNSTAGED_ICON='' 
	typeset -g -i _p9k_timewarrior_file_mtime=0 
	typeset -g -F _POWERLEVEL9K_LOAD_WARNING_PCT=50.0000000000 
	typeset -g -A _p9k_asdf_file_info=() 
	typeset -g -i _POWERLEVEL9K_VCS_COMMITS_BEHIND_MAX_NUM=1 
	typeset -g -i _POWERLEVEL9K_PROMPT_ON_NEWLINE=0 
	typeset -g -i _POWERLEVEL9K_STATUS_HIDE_SIGNAME=0 
	typeset -g -i _POWERLEVEL9K_PERLBREW_SHOW_PREFIX=0 
	typeset -g _POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='#F3F99D' 
	typeset -g -a _POWERLEVEL9K_VCS_GIT_HOOKS=(vcs-detect-changes git-untracked git-aheadbehind) 
	typeset -g -i _POWERLEVEL9K_VCS_SHOW_SUBMODULE_DIRTY=0 
	typeset -g -a _p9k_line_segments_right=('') 
	typeset -g -i _POWERLEVEL9K_DIR_PATH_ABSOLUTE=0 
	typeset -g _POWERLEVEL9K_VIRTUALENV_RIGHT_DELIMITER='' 
	typeset -g -i _POWERLEVEL9K_STATUS_SHOW_PIPESTATUS=1 
	typeset -g _p9k_uname_m=x86_64 
	typeset -g -i _POWERLEVEL9K_ALWAYS_SHOW_USER=0 
	typeset -g -i _POWERLEVEL9K_PROMPT_ADD_NEWLINE_COUNT=1 
	typeset -g _p9k_uname_o=GNU/Linux 
	typeset -g _POWERLEVEL9K_IP_INTERFACE='' 
	typeset -g -i _POWERLEVEL9K_VCS_RECURSE_UNTRACKED_DIRS=0 
	typeset -g -A _p9k_asdf_file2versions=() 
	typeset -g _p9k_gcloud_project_id='' 
	typeset -g -i _POWERLEVEL9K_STATUS_VERBOSE_SIGNAME=1 
	typeset -g _POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_FOREGROUND='#FF6AC1' 
	typeset -g -i _POWERLEVEL9K_COMMANDS_MAX_TOKEN_COUNT=64 
	typeset -g -a _p9k_taskwarrior_meta_files=() 
	typeset -g -F _POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS=0.0000000000 
	typeset -g _POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' ' 
	typeset -g _POWERLEVEL9K_VI_COMMAND_MODE_STRING=NORMAL 
	typeset -g -i _POWERLEVEL9K_STATUS_EXTENDED_STATES=0 
	typeset -g -i _POWERLEVEL9K_PERLBREW_PROJECT_ONLY=1 
	typeset -g -a _POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs command_execution_time virtualenv prompt_char) 
	typeset -g -i _POWERLEVEL9K_NVM_SHOW_SYSTEM=1 
	typeset -g _POWERLEVEL9K_PUBLIC_IP_VPN_INTERFACE='' 
	typeset -g -i _p9k_emulate_zero_rprompt_indent=0 
	typeset -g _POWERLEVEL9K_DIR_MAX_LENGTH=0 
	typeset -g -i _POWERLEVEL9K_DISABLE_INSTANT_PROMPT=0 
	typeset -g -i _POWERLEVEL9K_BATTERY_HIDE_ABOVE_THRESHOLD=999 
	typeset -g -a _p9k_taskwarrior_data_files=() 
	typeset -g _POWERLEVEL9K_HOST_TEMPLATE=%m 
	typeset -g -a _POWERLEVEL9K_BATTERY_LEVEL_FOREGROUND=() 
	typeset -g -a _POWERLEVEL9K_PYENV_SOURCES=(shell local global) 
	typeset -g -a _POWERLEVEL9K_BATTERY_CHARGING_LEVEL_FOREGROUND=() 
	typeset -g -i _POWERLEVEL9K_NIX_SHELL_INFER_FROM_PATH=0 
	typeset -g -i _POWERLEVEL9K_TODO_HIDE_ZERO_TOTAL=0 
	typeset -g -i _POWERLEVEL9K_LOAD_WHICH=2 
	typeset -g _p9k_timewarrior_file_name='' 
	typeset -g -i _POWERLEVEL9K_KUBECONTEXT_SHOW_DEFAULT_NAMESPACE=1 
	typeset -g -F _POWERLEVEL9K_NEW_TTY_MAX_AGE_SECONDS=5.0000000000 
	typeset -g -i _POWERLEVEL9K_PYENV_SHOW_SYSTEM=1 
	typeset -g -a _POWERLEVEL9K_LUAENV_SOURCES=(shell local global) 
}
_p9k_right_prompt_segment () {
	if ! _p9k_cache_get "$0" "$1" "$2" "$3" "$4" "$_p9k__segment_index"
	then
		_p9k_color $1 BACKGROUND $2
		local bg_color=$_p9k__ret 
		_p9k_background $bg_color
		local bg=$_p9k__ret 
		local bg_=${_p9k__ret//\}/\\\}} 
		_p9k_color $1 FOREGROUND $3
		local fg_color=$_p9k__ret 
		_p9k_foreground $fg_color
		local fg=$_p9k__ret 
		local style=%b$bg$fg 
		local style_=${style//\}/\\\}} 
		_p9k_get_icon $1 RIGHT_SEGMENT_SEPARATOR
		local sep=$_p9k__ret 
		_p9k_escape $_p9k__ret
		local sep_=$_p9k__ret 
		_p9k_get_icon $1 RIGHT_SUBSEGMENT_SEPARATOR
		local subsep=$_p9k__ret 
		[[ $subsep == *%* ]] && subsep+=$style 
		local icon_
		if [[ -n $4 ]]
		then
			_p9k_get_icon $1 $4
			_p9k_escape $_p9k__ret
			icon_=$_p9k__ret 
		fi
		_p9k_get_icon $1 RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL $sep
		local start_sep=$_p9k__ret 
		[[ -n $start_sep ]] && start_sep="%b%k%F{$bg_color}$start_sep" 
		_p9k_get_icon $1 RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL
		_p9k_escape $_p9k__ret
		local end_sep_=$_p9k__ret 
		_p9k_get_icon $1 WHITESPACE_BETWEEN_RIGHT_SEGMENTS ' '
		local space=$_p9k__ret 
		_p9k_get_icon $1 RIGHT_LEFT_WHITESPACE $space
		local left_space=$_p9k__ret 
		[[ $left_space == *%* ]] && left_space+=$style 
		_p9k_get_icon $1 RIGHT_RIGHT_WHITESPACE $space
		_p9k_escape $_p9k__ret
		local right_space_=$_p9k__ret 
		[[ $right_space_ == *%* ]] && right_space_+=$style_ 
		local w='<_p9k__w>' s='<_p9k__s>' 
		local -i non_hermetic=0 
		local t=$(($#_p9k_t - __p9k_ksh_arrays)) 
		_p9k_t+=$start_sep$style$left_space 
		_p9k_t+=$w$style 
		_p9k_t+=$w$style$subsep$left_space 
		_p9k_t+=$w%F{$bg_color}$sep$style$left_space 
		local join="_p9k__i>=$_p9k_right_join[$_p9k__segment_index]" 
		_p9k_param $1 SELF_JOINED false
		if [[ $_p9k__ret == false ]]
		then
			if (( _p9k__segment_index > $_p9k_right_join[$_p9k__segment_index] ))
			then
				join+="&&_p9k__i<$_p9k__segment_index" 
			else
				join= 
			fi
		fi
		local p= 
		p+="\${_p9k__n::=}" 
		p+="\${\${\${_p9k__bg:-0}:#NONE}:-\${_p9k__n::=$((t+1))}}" 
		if [[ -n $join ]]
		then
			p+="\${_p9k__n:=\${\${\$(($join)):#0}:+$((t+2))}}" 
		fi
		if (( __p9k_sh_glob ))
		then
			p+="\${_p9k__n:=\${\${(M)\${:-x\$_p9k__bg}:#x${(b)bg_color}}:+$((t+3))}}" 
			p+="\${_p9k__n:=\${\${(M)\${:-x\$_p9k__bg}:#x${(b)bg_color:-0}}:+$((t+3))}}" 
		else
			p+="\${_p9k__n:=\${\${(M)\${:-x\$_p9k__bg}:#x(${(b)bg_color}|${(b)bg_color:-0})}:+$((t+3))}}" 
		fi
		p+="\${_p9k__n:=$((t+4))}" 
		_p9k_param $1 VISUAL_IDENTIFIER_EXPANSION '${P9K_VISUAL_IDENTIFIER}'
		[[ $_p9k__ret == (|*[^\\])'$('* ]] && non_hermetic=1 
		local icon_exp_=${_p9k__ret:+\"$_p9k__ret\"} 
		_p9k_param $1 CONTENT_EXPANSION '${P9K_CONTENT}'
		[[ $_p9k__ret == (|*[^\\])'$('* ]] && non_hermetic=1 
		local content_exp_=${_p9k__ret:+\"$_p9k__ret\"} 
		if [[ ( $icon_exp_ != '"${P9K_VISUAL_IDENTIFIER}"' && $icon_exp_ == *'$'* ) || ( $content_exp_ != '"${P9K_CONTENT}"' && $content_exp_ == *'$'* ) ]]
		then
			p+="\${P9K_VISUAL_IDENTIFIER::=$icon_}" 
		fi
		local -i has_icon=-1 
		if [[ $icon_exp_ != '"${P9K_VISUAL_IDENTIFIER}"' && $icon_exp_ == *'$'* ]]
		then
			p+="\${_p9k__v::=$icon_exp_$style_}" 
		else
			[[ $icon_exp_ == '"${P9K_VISUAL_IDENTIFIER}"' ]] && _p9k__ret=$icon_  || _p9k__ret=$icon_exp_ 
			if [[ -n $_p9k__ret ]]
			then
				p+="\${_p9k__v::=$_p9k__ret" 
				[[ $_p9k__ret == *%* ]] && p+=$style_ 
				p+="}" 
				has_icon=1 
			else
				has_icon=0 
			fi
		fi
		p+='${_p9k__c::='$content_exp_'}${_p9k__c::=${_p9k__c//'$'\r''}}' 
		p+='${_p9k__e::=${${_p9k__'${_p9k__line_index}r${${1#prompt_}%%[A-Z0-9_]#}'+00}:-' 
		if (( has_icon == -1 ))
		then
			p+='${${(%):-$_p9k__c%1(l.1.0)}[-1]}${${(%):-$_p9k__v%1(l.1.0)}[-1]}}' 
		else
			p+='${${(%):-$_p9k__c%1(l.1.0)}[-1]}'$has_icon'}' 
		fi
		p+='}}+}' 
		p+='${${_p9k__e:#00}:+${_p9k_t[$_p9k__n]/'$w'/$_p9k__w}' 
		_p9k_param $1 ICON_BEFORE_CONTENT ''
		if [[ $_p9k__ret != true ]]
		then
			_p9k_param $1 PREFIX ''
			_p9k__ret=${(g::)_p9k__ret} 
			_p9k_escape $_p9k__ret
			p+=$_p9k__ret 
			[[ $_p9k__ret == *%* ]] && p+=$style_ 
			p+='${_p9k__c}'$style_ 
			if (( has_icon != 0 ))
			then
				local -i need_style=0 
				_p9k_get_icon $1 RIGHT_MIDDLE_WHITESPACE ' '
				if [[ -n $_p9k__ret ]]
				then
					_p9k_escape $_p9k__ret
					[[ $_p9k__ret == *%* ]] && need_style=1 
					p+='${${(M)_p9k__e:#11}:+'$_p9k__ret'}' 
				fi
				_p9k_color $1 VISUAL_IDENTIFIER_COLOR $fg_color
				_p9k_foreground $_p9k__ret
				_p9k__ret=%b$bg$_p9k__ret 
				_p9k__ret=${_p9k__ret//\}/\\\}} 
				[[ $_p9k__ret != $style_ || $need_style == 1 ]] && p+=$_p9k__ret 
				p+='$_p9k__v' 
			fi
		else
			_p9k_param $1 PREFIX ''
			_p9k__ret=${(g::)_p9k__ret} 
			_p9k_escape $_p9k__ret
			p+=$_p9k__ret 
			[[ $_p9k__ret == *%* ]] && local -i need_style=1  || local -i need_style=0 
			if (( has_icon != 0 ))
			then
				_p9k_color $1 VISUAL_IDENTIFIER_COLOR $fg_color
				_p9k_foreground $_p9k__ret
				_p9k__ret=%b$bg$_p9k__ret 
				_p9k__ret=${_p9k__ret//\}/\\\}} 
				if [[ $_p9k__ret != $style_ ]]
				then
					p+=$_p9k__ret'${_p9k__v}'$style_ 
				else
					(( need_style )) && p+=$style_ 
					p+='${_p9k__v}' 
				fi
				_p9k_get_icon $1 RIGHT_MIDDLE_WHITESPACE ' '
				if [[ -n $_p9k__ret ]]
				then
					_p9k_escape $_p9k__ret
					[[ _p9k__ret == *%* ]] && _p9k__ret+=$style_ 
					p+='${${(M)_p9k__e:#11}:+'$_p9k__ret'}' 
				fi
			elif (( need_style ))
			then
				p+=$style_ 
			fi
			p+='${_p9k__c}'$style_ 
		fi
		_p9k_param $1 SUFFIX ''
		_p9k__ret=${(g::)_p9k__ret} 
		_p9k_escape $_p9k__ret
		p+=$_p9k__ret 
		p+='${${:-' 
		if [[ -n $fg_color && $fg_color == $bg_color ]]
		then
			if [[ $fg_color == $_p9k_color1 ]]
			then
				_p9k_foreground $_p9k_color2
			else
				_p9k_foreground $_p9k_color1
			fi
		else
			_p9k__ret=$fg 
		fi
		_p9k__ret=${_p9k__ret//\}/\\\}} 
		p+="\${_p9k__w::=${right_space_:+$style_}$right_space_%b$bg_$_p9k__ret}" 
		p+='${_p9k__sss::=' 
		p+=$style_$right_space_ 
		[[ $right_space_ == *%* ]] && p+=$style_ 
		if [[ -n $end_sep_ ]]
		then
			p+="%k%F{$bg_color\}$end_sep_$style_" 
		fi
		p+='}' 
		p+="\${_p9k__i::=$_p9k__segment_index}\${_p9k__bg::=$bg_color}" 
		p+='}+}' 
		p+='}' 
		_p9k_param $1 SHOW_ON_UPGLOB ''
		_p9k_cache_set "$p" $non_hermetic $_p9k__ret
	fi
	if [[ -n $_p9k__cache_val[3] ]]
	then
		_p9k__has_upglob=1 
		_p9k_upglob $_p9k__cache_val[3] && return
	fi
	_p9k__non_hermetic_expansion=$_p9k__cache_val[2] 
	(( $5 )) && _p9k__ret=\"$7\"  || _p9k_escape $7
	if [[ -z $6 ]]
	then
		_p9k__prompt+="\${\${:-\${P9K_CONTENT::=$_p9k__ret}$_p9k__cache_val[1]" 
	else
		_p9k__prompt+="\${\${:-\"$6\"}:+\${\${:-\${P9K_CONTENT::=$_p9k__ret}$_p9k__cache_val[1]}" 
	fi
}
_p9k_rust_version_prefetch () {
	local rustc=$commands[rustc] 
	if [[ -z $rustc ]] || {
			(( _POWERLEVEL9K_RUST_VERSION_PROJECT_ONLY )) && _p9k_upglob Cargo.toml -.
		}
	then
		unset P9K_RUST_VERSION
		return
	fi
	_p9k_worker_invoke rust_version "_p9k_prompt_rust_version_compute ${(q)P9K_RUST_VERSION} ${(q)rustc} ${(q)_p9k__cwd_a}"
}
_p9k_save_status () {
	local -i pipe
	if (( !$+_p9k__line_finished ))
	then
		:
	elif (( !$+_p9k__preexec_cmd ))
	then
		(( _p9k__status == __p9k_new_status )) && return
	elif (( $__p9k_new_pipestatus[(I)$__p9k_new_status] ))
	then
		local cmd=(${(z)_p9k__preexec_cmd}) 
		if [[ $#cmd != 0 && $cmd[1] != '!' && ${(Q)cmd[1]} != coproc ]]
		then
			local arg
			for arg in ${(z)_p9k__preexec_cmd}
			do
				if [[ $arg == ('()'|'&&'|'||'|'&'|'&|'|'&!'|*';') ]]
				then
					pipe=0 
					break
				elif [[ $arg == *('|'|'|&')* ]]
				then
					pipe=1 
				fi
			done
		fi
	fi
	_p9k__status=$__p9k_new_status 
	if (( pipe ))
	then
		_p9k__pipestatus=($__p9k_new_pipestatus) 
	else
		_p9k__pipestatus=($_p9k__status) 
	fi
}
_p9k_scalaenv_global_version () {
	_p9k_read_word ${SCALAENV_ROOT:-$HOME/.scalaenv}/version || _p9k__ret=system 
}
_p9k_segment_in_use () {
	(( $_POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[(I)$1(|_joined)] ||
     $_POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS[(I)$1(|_joined)] ))
}
_p9k_set_instant_prompt () {
	local saved_prompt=$PROMPT 
	local saved_rprompt=$RPROMPT 
	_p9k_set_prompt instant_
	typeset -g _p9k__instant_prompt=$PROMPT$'\x1f'$_p9k__prompt$'\x1f'$RPROMPT 
	PROMPT=$saved_prompt 
	RPROMPT=$saved_rprompt 
	[[ -n $RPROMPT ]] || unset RPROMPT
}
_p9k_set_os () {
	_p9k_os=$1 
	_p9k_get_icon prompt_os_icon $2
	_p9k_os_icon=$_p9k__ret 
}
_p9k_set_prompt () {
	local -i _p9k__vcs_called
	PROMPT= 
	RPROMPT= 
	[[ $1 == instant_ ]] || PROMPT+='${$((_p9k_on_expand()))+}%{${_p9k__raw_msg-}${_p9k__raw_msg::=}%}' 
	PROMPT+=$_p9k_prompt_prefix_left 
	local -i _p9k__has_upglob
	local -i left_idx=1 right_idx=1 num_lines=$#_p9k_line_segments_left 
	for _p9k__line_index in {1..$num_lines}
	do
		local right= 
		if (( !_POWERLEVEL9K_DISABLE_RPROMPT ))
		then
			_p9k__dir= 
			_p9k__prompt= 
			_p9k__segment_index=right_idx 
			_p9k__prompt_side=right 
			if [[ $1 == instant_ ]]
			then
				for _p9k__segment_name in ${${(0)_p9k_line_segments_right[_p9k__line_index]}%_joined}
				do
					if (( $+functions[instant_prompt_$_p9k__segment_name] ))
					then
						local disabled=_POWERLEVEL9K_${${(U)_p9k__segment_name}//İ/I}_DISABLED_DIR_PATTERN 
						if [[ $_p9k__cwd != ${(P)~disabled} ]]
						then
							local -i len=$#_p9k__prompt 
							_p9k__non_hermetic_expansion=0 
							instant_prompt_$_p9k__segment_name
							if (( _p9k__non_hermetic_expansion ))
							then
								_p9k__prompt[len+1,-1]= 
							fi
						fi
					fi
					((++_p9k__segment_index))
				done
			else
				for _p9k__segment_name in ${${(0)_p9k_line_segments_right[_p9k__line_index]}%_joined}
				do
					local cond=$_p9k__segment_cond_right[_p9k__segment_index] 
					if [[ -z $cond || -n ${(e)cond} ]]
					then
						local disabled=_POWERLEVEL9K_${${(U)_p9k__segment_name}//İ/I}_DISABLED_DIR_PATTERN 
						if [[ $_p9k__cwd != ${(P)~disabled} ]]
						then
							local val=$_p9k__segment_val_right[_p9k__segment_index] 
							if [[ -n $val ]]
							then
								_p9k__prompt+=$val 
							else
								if [[ $_p9k__segment_name == custom_* ]]
								then
									_p9k_custom_prompt $_p9k__segment_name[8,-1]
								elif (( $+functions[prompt_$_p9k__segment_name] ))
								then
									prompt_$_p9k__segment_name
								fi
							fi
						fi
					fi
					((++_p9k__segment_index))
				done
			fi
			_p9k__prompt=${${_p9k__prompt//$' %{\b'/'%{%G'}//$' \b'} 
			right_idx=_p9k__segment_index 
			if [[ -n $_p9k__prompt || $_p9k_line_never_empty_right[_p9k__line_index] == 1 ]]
			then
				right=$_p9k_line_prefix_right[_p9k__line_index]$_p9k__prompt$_p9k_line_suffix_right[_p9k__line_index] 
			fi
		fi
		unset _p9k__dir
		_p9k__prompt=$_p9k_line_prefix_left[_p9k__line_index] 
		_p9k__segment_index=left_idx 
		_p9k__prompt_side=left 
		if [[ $1 == instant_ ]]
		then
			for _p9k__segment_name in ${${(0)_p9k_line_segments_left[_p9k__line_index]}%_joined}
			do
				if (( $+functions[instant_prompt_$_p9k__segment_name] ))
				then
					local disabled=_POWERLEVEL9K_${${(U)_p9k__segment_name}//İ/I}_DISABLED_DIR_PATTERN 
					if [[ $_p9k__cwd != ${(P)~disabled} ]]
					then
						local -i len=$#_p9k__prompt 
						_p9k__non_hermetic_expansion=0 
						instant_prompt_$_p9k__segment_name
						if (( _p9k__non_hermetic_expansion ))
						then
							_p9k__prompt[len+1,-1]= 
						fi
					fi
				fi
				((++_p9k__segment_index))
			done
		else
			for _p9k__segment_name in ${${(0)_p9k_line_segments_left[_p9k__line_index]}%_joined}
			do
				local cond=$_p9k__segment_cond_left[_p9k__segment_index] 
				if [[ -z $cond || -n ${(e)cond} ]]
				then
					local disabled=_POWERLEVEL9K_${${(U)_p9k__segment_name}//İ/I}_DISABLED_DIR_PATTERN 
					if [[ $_p9k__cwd != ${(P)~disabled} ]]
					then
						local val=$_p9k__segment_val_left[_p9k__segment_index] 
						if [[ -n $val ]]
						then
							_p9k__prompt+=$val 
						else
							if [[ $_p9k__segment_name == custom_* ]]
							then
								_p9k_custom_prompt $_p9k__segment_name[8,-1]
							elif (( $+functions[prompt_$_p9k__segment_name] ))
							then
								prompt_$_p9k__segment_name
							fi
						fi
					fi
				fi
				((++_p9k__segment_index))
			done
		fi
		_p9k__prompt=${${_p9k__prompt//$' %{\b'/'%{%G'}//$' \b'} 
		left_idx=_p9k__segment_index 
		_p9k__prompt+=$_p9k_line_suffix_left[_p9k__line_index] 
		if (( $+_p9k__dir || (_p9k__line_index != num_lines && $#right) ))
		then
			_p9k__prompt='${${:-${_p9k__d::=0}${_p9k__rprompt::='$right'}${_p9k__lprompt::='$_p9k__prompt'}}+}' 
			_p9k__prompt+=$_p9k_gap_pre 
			if (( $+_p9k__dir ))
			then
				if (( _p9k__line_index == num_lines && (_POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS > 0 || _POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT > 0) ))
				then
					local a=$_POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS 
					local f=$((0.01*_POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT))'*_p9k__clm' 
					_p9k__prompt+="\${\${_p9k__h::=$((($a<$f)*$f+($a>=$f)*$a))}+}" 
				else
					_p9k__prompt+='${${_p9k__h::=0}+}' 
				fi
				if [[ $_POWERLEVEL9K_DIR_MAX_LENGTH == <->('%'|) ]]
				then
					local lim= 
					if [[ $_POWERLEVEL9K_DIR_MAX_LENGTH[-1] == '%' ]]
					then
						lim="$_p9k__dir_len-$((0.01*$_POWERLEVEL9K_DIR_MAX_LENGTH[1,-2]))*_p9k__clm" 
					else
						lim=$((_p9k__dir_len-_POWERLEVEL9K_DIR_MAX_LENGTH)) 
						((lim <= 0)) && lim= 
					fi
					if [[ -n $lim ]]
					then
						_p9k__prompt+='${${${$((_p9k__h<_p9k__m+'$lim')):#1}:-${_p9k__h::=$((_p9k__m+'$lim'))}}+}' 
					fi
				fi
				_p9k__prompt+='${${_p9k__d::=$((_p9k__m-_p9k__h))}+}' 
				_p9k__prompt+='${_p9k__lprompt/\%\{d\%\}*\%\{d\%\}/${_p9k__'$_p9k__line_index'ldir-'$_p9k__dir'}}' 
				_p9k__prompt+='${${_p9k__m::=$((_p9k__d+_p9k__h))}+}' 
			else
				_p9k__prompt+='${_p9k__lprompt}' 
			fi
			((_p9k__line_index != num_lines && $#right)) && _p9k__prompt+=$_p9k_line_gap_post[_p9k__line_index] 
		fi
		if (( _p9k__line_index == num_lines ))
		then
			[[ -n $right ]] && RPROMPT=$_p9k_prompt_prefix_right$right$_p9k_prompt_suffix_right 
			_p9k__prompt='${_p9k__'$_p9k__line_index'-'$_p9k__prompt'}'$_p9k_prompt_suffix_left 
			[[ $1 == instant_ ]] || PROMPT+=$_p9k__prompt 
		else
			[[ -n $right ]] || _p9k__prompt+=$'\n' 
			PROMPT+='${_p9k__'$_p9k__line_index'-'$_p9k__prompt'}' 
		fi
	done
	_p9k__prompt_side= 
	(( $#_p9k_cache < _POWERLEVEL9K_MAX_CACHE_SIZE )) || _p9k_cache=() 
	(( $#_p9k__cache_ephemeral < _POWERLEVEL9K_MAX_CACHE_SIZE )) || _p9k__cache_ephemeral=() 
	[[ -n $RPROMPT ]] || unset RPROMPT
}
_p9k_setup () {
	(( __p9k_enabled )) && return
	prompt_opts=(percent subst) 
	if (( ! $+__p9k_instant_prompt_active ))
	then
		prompt_opts+=sp 
		prompt_opts+=cr 
	fi
	prompt_powerlevel9k_teardown
	__p9k_enabled=1 
	typeset -ga preexec_functions=(_p9k_preexec1 $preexec_functions _p9k_preexec2) 
	typeset -ga precmd_functions=(_p9k_do_nothing _p9k_precmd_first $precmd_functions _p9k_precmd) 
}
_p9k_shorten_delim_len () {
	local def=$1 
	_p9k__ret=${_POWERLEVEL9K_SHORTEN_DELIMITER_LENGTH:--1} 
	(( _p9k__ret >= 0 )) || _p9k_prompt_length $1
}
_p9k_should_dump () {
	(( __p9k_dumps_enabled && ! _p9k__state_dump_fd )) || return
	(( _p9k__state_dump_scheduled || _p9k__prompt_idx == 1 )) && return
	_p9k__instant_prompt_sig=$_p9k__cwd:$P9K_SSH:${(%):-%#} 
	(( ! $+_p9k_dumped_instant_prompt_sigs[$_p9k__instant_prompt_sig] ))
}
_p9k_taskwarrior_check_data () {
	[[ -n $_p9k_taskwarrior_data_sig ]] || return
	[[ -z $^_p9k_taskwarrior_data_non_files(#qN) ]] || return
	local -a stat
	if (( $#_p9k_taskwarrior_data_files ))
	then
		zstat -A stat +mtime -- $_p9k_taskwarrior_data_files 2> /dev/null || return
	fi
	[[ $_p9k_taskwarrior_data_sig == ${(pj:\0:)stat}$'\0'$TASKRC$'\0'$TASKDATA ]] || return
	(( _p9k_taskwarrior_next_due == 0 || _p9k_taskwarrior_next_due > EPOCHSECONDS )) || return
}
_p9k_taskwarrior_check_meta () {
	[[ -n $_p9k_taskwarrior_meta_sig ]] || return
	[[ -z $^_p9k_taskwarrior_meta_non_files(#qN) ]] || return
	local -a stat
	if (( $#_p9k_taskwarrior_meta_files ))
	then
		zstat -A stat +mtime -- $_p9k_taskwarrior_meta_files 2> /dev/null || return
	fi
	[[ $_p9k_taskwarrior_meta_sig == ${(pj:\0:)stat}$'\0'$TASKRC$'\0'$TASKDATA ]] || return
}
_p9k_taskwarrior_init_data () {
	local -a stat files=($_p9k_taskwarrior_data_dir/{pending,completed}.data $_p9k_taskwarrior_data_dir/taskchampion.sqlite3) 
	_p9k_taskwarrior_data_files=($^files(N)) 
	_p9k_taskwarrior_data_non_files=(${files:|_p9k_taskwarrior_data_files}) 
	if (( $#_p9k_taskwarrior_data_files ))
	then
		zstat -A stat +mtime -- $_p9k_taskwarrior_data_files 2> /dev/null || stat=(-1) 
		_p9k_taskwarrior_data_sig=${(pj:\0:)stat}$'\0' 
	else
		_p9k_taskwarrior_data_sig= 
	fi
	_p9k_taskwarrior_data_files+=($_p9k_taskwarrior_meta_files) 
	_p9k_taskwarrior_data_non_files+=($_p9k_taskwarrior_meta_non_files) 
	_p9k_taskwarrior_data_sig+=$_p9k_taskwarrior_meta_sig 
	local name val
	for name in PENDING OVERDUE
	do
		val="$(command task +$name count rc.color=0 rc._forcecolor=0 </dev/null 2>/dev/null)"  || continue
		[[ $val == <1-> ]] || continue
		_p9k_taskwarrior_counters[$name]=$val 
	done
	_p9k_taskwarrior_next_due=0 
	if (( _p9k_taskwarrior_counters[PENDING] > _p9k_taskwarrior_counters[OVERDUE] ))
	then
		local -a ts
		ts=($(command task +PENDING -OVERDUE list rc.verbose=nothing rc.color=0 rc._forcecolor=0 \
      rc.report.list.labels= rc.report.list.columns=due.epoch </dev/null 2>/dev/null))  || ts=() 
		if (( $#ts && ! ${#${(@)ts:#(|-)<->(|.<->)}} ))
		then
			_p9k_taskwarrior_next_due=${${(on)ts}[1]} 
			(( _p9k_taskwarrior_next_due > EPOCHSECONDS )) || _p9k_taskwarrior_next_due=$((EPOCHSECONDS+60)) 
		fi
	fi
	_p9k__state_dump_scheduled=1 
}
_p9k_taskwarrior_init_meta () {
	local last_sig=$_p9k_taskwarrior_meta_sig 
	{
		local cfg
		cfg="$(command task show data.location rc.color=0 rc._forcecolor=0 </dev/null 2>/dev/null)"  || return
		local lines=(${(@M)${(f)cfg}:#data.location[[:space:]]##[^[:space:]]*}) 
		(( $#lines == 1 )) || return
		local dir=${lines[1]##data.location[[:space:]]#} 
		: ${dir::=$~dir}
		local -a stat files=(${TASKRC:-~/.taskrc}) 
		_p9k_taskwarrior_meta_files=($^files(N)) 
		_p9k_taskwarrior_meta_non_files=(${files:|_p9k_taskwarrior_meta_files}) 
		if (( $#_p9k_taskwarrior_meta_files ))
		then
			zstat -A stat +mtime -- $_p9k_taskwarrior_meta_files 2> /dev/null || stat=(-1) 
		fi
		_p9k_taskwarrior_meta_sig=${(pj:\0:)stat}$'\0'$TASKRC$'\0'$TASKDATA 
		_p9k_taskwarrior_data_dir=$dir 
	} always {
		if (( $? == 0 ))
		then
			_p9k__state_dump_scheduled=1 
			return
		fi
		[[ -n $last_sig ]] && _p9k__state_dump_scheduled=1 
		_p9k_taskwarrior_meta_files=() 
		_p9k_taskwarrior_meta_non_files=() 
		_p9k_taskwarrior_meta_sig= 
		_p9k_taskwarrior_data_dir= 
		_p9k__taskwarrior_functional= 
	}
}
_p9k_timewarrior_clear () {
	[[ -z $_p9k_timewarrior_dir ]] && return
	_p9k_timewarrior_dir= 
	_p9k_timewarrior_dir_mtime=0 
	_p9k_timewarrior_file_mtime=0 
	_p9k_timewarrior_file_name= 
	unset _p9k_timewarrior_tags
	_p9k__state_dump_scheduled=1 
}
_p9k_translate_color () {
	if [[ $1 == <-> ]]
	then
		_p9k__ret=${(l.3..0.)1} 
	elif [[ $1 == '#'[[:xdigit:]]## ]]
	then
		_p9k__ret=${${(L)1}//ı/i} 
	else
		_p9k__ret=$__p9k_colors[${${${1#bg-}#fg-}#br}] 
	fi
}
_p9k_trapint () {
	if (( __p9k_enabled ))
	then
		eval "$__p9k_intro"
		_p9k_deschedule_redraw
		zle && _p9k_on_widget_zle-line-finish int
	fi
	return 0
}
_p9k_upglob () {
	local cached=$_p9k__upsearch_cache[$_p9k__cwd/$1] 
	if [[ -n $cached ]]
	then
		if [[ $_p9k__parent_mtimes_s == ${cached% *}(| *) ]]
		then
			return ${cached##* }
		fi
		cached=(${(s: :)cached}) 
		local last_idx=$cached[-1] 
		cached[-1]=() 
		local -i i
		for i in ${(@)${cached:|_p9k__parent_mtimes_i}%:*}
		do
			_p9k_glob $i "$@" && continue
			_p9k__upsearch_cache[$_p9k__cwd/$1]="${_p9k__parent_mtimes_i[1,i]} $i" 
			return i
		done
		if (( i != last_idx ))
		then
			_p9k__upsearch_cache[$_p9k__cwd/$1]="${_p9k__parent_mtimes_i[1,$#cached]} $last_idx" 
			return last_idx
		fi
		i=$(($#cached + 1)) 
	else
		local -i i=1 
	fi
	for ((; i <= $#_p9k__parent_mtimes; ++i)) do
		_p9k_glob $i "$@" && continue
		_p9k__upsearch_cache[$_p9k__cwd/$1]="${_p9k__parent_mtimes_i[1,i]} $i" 
		return i
	done
	_p9k__upsearch_cache[$_p9k__cwd/$1]="$_p9k__parent_mtimes_s 0" 
	return 0
}
_p9k_url_escape () {
	emulate -L zsh -o no_multi_byte -o extended_glob
	local MATCH MBEGIN MEND
	_p9k__ret=${1//(#m)[^a-zA-Z0-9"\/:_.-!'()~"]/%%${(l:2::0:)$(([##16]#MATCH))}} 
}
_p9k_vcs_gitstatus () {
	if [[ $_p9k__refresh_reason == precmd ]] && (( !_p9k__vcs_called ))
	then
		typeset -gi _p9k__vcs_called=1 
		if (( $+_p9k__gitstatus_next_dir ))
		then
			_p9k__gitstatus_next_dir=$_p9k__cwd_a 
		else
			local -F timeout=_POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS 
			if ! _p9k_vcs_status_for_dir
			then
				_p9k__git_dir=$GIT_DIR 
				gitstatus_query_p9k_ -d $_p9k__cwd_a -t $timeout -p -c '_p9k_vcs_resume 0' POWERLEVEL9K || return 1
				_p9k_maybe_ignore_git_repo
				case $VCS_STATUS_RESULT in
					(tout) _p9k__gitstatus_next_dir='' 
						_p9k__gitstatus_start_time=$EPOCHREALTIME 
						return 0 ;;
					(norepo-sync) return 0 ;;
					(ok-sync) _p9k_vcs_status_save ;;
				esac
			else
				if [[ -n $GIT_DIR ]]
				then
					[[ $_p9k_git_slow[GIT_DIR:$GIT_DIR] == 1 ]] && timeout=0 
				else
					local dir=$_p9k__cwd_a 
					while true
					do
						case $_p9k_git_slow[$dir] in
							("") [[ $dir == (/|.) ]] && break
								dir=${dir:h}  ;;
							(0) break ;;
							(1) timeout=0 
								break ;;
						esac
					done
				fi
			fi
			(( _p9k__prompt_idx == 1 )) && timeout=0 
			_p9k__git_dir=$GIT_DIR 
			if (( _p9k_vcs_index && $+GITSTATUS_DAEMON_PID_POWERLEVEL9K ))
			then
				if ! gitstatus_query_p9k_ -d $_p9k__cwd_a -t 0 -c '_p9k_vcs_resume 1' POWERLEVEL9K
				then
					unset VCS_STATUS_RESULT
					return 1
				fi
				typeset -gF _p9k__vcs_timeout=timeout 
				_p9k__gitstatus_next_dir='' 
				_p9k__gitstatus_start_time=$EPOCHREALTIME 
				return 0
			fi
			if ! gitstatus_query_p9k_ -d $_p9k__cwd_a -t $timeout -c '_p9k_vcs_resume 1' POWERLEVEL9K
			then
				unset VCS_STATUS_RESULT
				return 1
			fi
			_p9k_maybe_ignore_git_repo
			case $VCS_STATUS_RESULT in
				(tout) _p9k__gitstatus_next_dir='' 
					_p9k__gitstatus_start_time=$EPOCHREALTIME  ;;
				(norepo-sync) _p9k_vcs_status_purge $_p9k__cwd_a ;;
				(ok-sync) _p9k_vcs_status_save ;;
			esac
		fi
	fi
	return 0
}
_p9k_vcs_icon () {
	local pat icon
	for pat icon in "${(@)_POWERLEVEL9K_VCS_GIT_REMOTE_ICONS}"
	do
		if [[ $1 == $~pat ]]
		then
			_p9k__ret=$icon 
			return
		fi
	done
	_p9k__ret= 
}
_p9k_vcs_info_init () {
	autoload -Uz vcs_info
	local prefix='' 
	if (( _POWERLEVEL9K_SHOW_CHANGESET ))
	then
		_p9k_get_icon '' VCS_COMMIT_ICON
		prefix="$_p9k__ret%0.${_POWERLEVEL9K_CHANGESET_HASH_LENGTH}i " 
	fi
	zstyle ':vcs_info:*' check-for-changes true
	zstyle ':vcs_info:*' formats "$prefix%b%c%u%m"
	zstyle ':vcs_info:*' actionformats "%b %F{$_POWERLEVEL9K_VCS_ACTIONFORMAT_FOREGROUND}| %a%f"
	_p9k_get_icon '' VCS_STAGED_ICON
	zstyle ':vcs_info:*' stagedstr " $_p9k__ret"
	_p9k_get_icon '' VCS_UNSTAGED_ICON
	zstyle ':vcs_info:*' unstagedstr " $_p9k__ret"
	zstyle ':vcs_info:git*+set-message:*' hooks $_POWERLEVEL9K_VCS_GIT_HOOKS
	zstyle ':vcs_info:hg*+set-message:*' hooks $_POWERLEVEL9K_VCS_HG_HOOKS
	zstyle ':vcs_info:svn*+set-message:*' hooks $_POWERLEVEL9K_VCS_SVN_HOOKS
	if (( _POWERLEVEL9K_HIDE_BRANCH_ICON ))
	then
		zstyle ':vcs_info:hg*:*' branchformat "%b"
	else
		_p9k_get_icon '' VCS_BRANCH_ICON
		zstyle ':vcs_info:hg*:*' branchformat "$_p9k__ret%b"
	fi
	zstyle ':vcs_info:hg*:*' get-revision true
	zstyle ':vcs_info:hg*:*' get-bookmarks true
	zstyle ':vcs_info:hg*+gen-hg-bookmark-string:*' hooks hg-bookmarks
	zstyle ':vcs_info:svn*:*' formats "$prefix%c%u"
	zstyle ':vcs_info:svn*:*' actionformats "$prefix%c%u %F{$_POWERLEVEL9K_VCS_ACTIONFORMAT_FOREGROUND}| %a%f"
	if (( _POWERLEVEL9K_SHOW_CHANGESET ))
	then
		zstyle ':vcs_info:*' get-revision true
	else
		zstyle ':vcs_info:*' get-revision false
	fi
}
_p9k_vcs_render () {
	local state
	if (( $+_p9k__gitstatus_next_dir ))
	then
		if _p9k_vcs_status_for_dir
		then
			_p9k_vcs_status_restore $_p9k__ret
			state=LOADING 
		else
			_p9k_prompt_segment prompt_vcs_LOADING "${__p9k_vcs_states[LOADING]}" "$_p9k_color1" VCS_LOADING_ICON 0 '' "$_POWERLEVEL9K_VCS_LOADING_TEXT"
			return 0
		fi
	elif [[ $VCS_STATUS_RESULT != ok-* ]]
	then
		return 1
	fi
	if (( _POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING ))
	then
		if [[ -z $state ]]
		then
			if [[ $VCS_STATUS_HAS_CONFLICTED == 1 && $_POWERLEVEL9K_VCS_CONFLICTED_STATE == 1 ]]
			then
				state=CONFLICTED 
			elif [[ $VCS_STATUS_HAS_STAGED != 0 || $VCS_STATUS_HAS_UNSTAGED != 0 ]]
			then
				state=MODIFIED 
			elif [[ $VCS_STATUS_HAS_UNTRACKED != 0 ]]
			then
				state=UNTRACKED 
			else
				state=CLEAN 
			fi
		fi
		_p9k_vcs_icon "$VCS_STATUS_REMOTE_URL"
		_p9k_prompt_segment prompt_vcs_$state "${__p9k_vcs_states[$state]}" "$_p9k_color1" "$_p9k__ret" 0 '' ""
		return 0
	fi
	(( ${_POWERLEVEL9K_VCS_GIT_HOOKS[(I)git-untracked]} )) || VCS_STATUS_HAS_UNTRACKED=0 
	(( ${_POWERLEVEL9K_VCS_GIT_HOOKS[(I)git-aheadbehind]} )) || {
		VCS_STATUS_COMMITS_AHEAD=0  && VCS_STATUS_COMMITS_BEHIND=0 
	}
	(( ${_POWERLEVEL9K_VCS_GIT_HOOKS[(I)git-stash]} )) || VCS_STATUS_STASHES=0 
	(( ${_POWERLEVEL9K_VCS_GIT_HOOKS[(I)git-remotebranch]} )) || VCS_STATUS_REMOTE_BRANCH="" 
	(( ${_POWERLEVEL9K_VCS_GIT_HOOKS[(I)git-tagname]} )) || VCS_STATUS_TAG="" 
	(( _POWERLEVEL9K_VCS_COMMITS_AHEAD_MAX_NUM >= 0 && VCS_STATUS_COMMITS_AHEAD > _POWERLEVEL9K_VCS_COMMITS_AHEAD_MAX_NUM )) && VCS_STATUS_COMMITS_AHEAD=$_POWERLEVEL9K_VCS_COMMITS_AHEAD_MAX_NUM 
	(( _POWERLEVEL9K_VCS_COMMITS_BEHIND_MAX_NUM >= 0 && VCS_STATUS_COMMITS_BEHIND > _POWERLEVEL9K_VCS_COMMITS_BEHIND_MAX_NUM )) && VCS_STATUS_COMMITS_BEHIND=$_POWERLEVEL9K_VCS_COMMITS_BEHIND_MAX_NUM 
	local -a cache_key=("$VCS_STATUS_LOCAL_BRANCH" "$VCS_STATUS_REMOTE_BRANCH" "$VCS_STATUS_REMOTE_URL" "$VCS_STATUS_ACTION" "$VCS_STATUS_NUM_STAGED" "$VCS_STATUS_NUM_UNSTAGED" "$VCS_STATUS_NUM_UNTRACKED" "$VCS_STATUS_HAS_CONFLICTED" "$VCS_STATUS_HAS_STAGED" "$VCS_STATUS_HAS_UNSTAGED" "$VCS_STATUS_HAS_UNTRACKED" "$VCS_STATUS_COMMITS_AHEAD" "$VCS_STATUS_COMMITS_BEHIND" "$VCS_STATUS_STASHES" "$VCS_STATUS_TAG" "$VCS_STATUS_NUM_UNSTAGED_DELETED") 
	if [[ $_POWERLEVEL9K_SHOW_CHANGESET == 1 || -z $VCS_STATUS_LOCAL_BRANCH ]]
	then
		cache_key+=$VCS_STATUS_COMMIT 
	fi
	if ! _p9k_cache_ephemeral_get "$state" "${(@)cache_key}"
	then
		local icon
		local content
		if (( ${_POWERLEVEL9K_VCS_GIT_HOOKS[(I)vcs-detect-changes]} ))
		then
			if [[ $VCS_STATUS_HAS_CONFLICTED == 1 && $_POWERLEVEL9K_VCS_CONFLICTED_STATE == 1 ]]
			then
				: ${state:=CONFLICTED}
			elif [[ $VCS_STATUS_HAS_STAGED != 0 || $VCS_STATUS_HAS_UNSTAGED != 0 ]]
			then
				: ${state:=MODIFIED}
			elif [[ $VCS_STATUS_HAS_UNTRACKED != 0 ]]
			then
				: ${state:=UNTRACKED}
			fi
			_p9k_vcs_icon "$VCS_STATUS_REMOTE_URL"
			icon=$_p9k__ret 
		fi
		: ${state:=CLEAN}
		_$0_fmt () {
			_p9k_vcs_style $state $1
			content+="$_p9k__ret$2" 
		}
		local ws
		if [[ $_POWERLEVEL9K_SHOW_CHANGESET == 1 || -z $VCS_STATUS_LOCAL_BRANCH ]]
		then
			_p9k_get_icon prompt_vcs_$state VCS_COMMIT_ICON
			_$0_fmt COMMIT "$_p9k__ret${${VCS_STATUS_COMMIT:0:$_POWERLEVEL9K_CHANGESET_HASH_LENGTH}:-HEAD}"
			ws=' ' 
		fi
		if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]
		then
			local branch=$ws 
			if (( !_POWERLEVEL9K_HIDE_BRANCH_ICON ))
			then
				_p9k_get_icon prompt_vcs_$state VCS_BRANCH_ICON
				branch+=$_p9k__ret 
			fi
			if (( $+_POWERLEVEL9K_VCS_SHORTEN_LENGTH && $+_POWERLEVEL9K_VCS_SHORTEN_MIN_LENGTH &&
            $#VCS_STATUS_LOCAL_BRANCH > _POWERLEVEL9K_VCS_SHORTEN_MIN_LENGTH &&
            $#VCS_STATUS_LOCAL_BRANCH > _POWERLEVEL9K_VCS_SHORTEN_LENGTH )) && [[ $_POWERLEVEL9K_VCS_SHORTEN_STRATEGY == (truncate_middle|truncate_from_right) ]]
			then
				branch+=${VCS_STATUS_LOCAL_BRANCH[1,_POWERLEVEL9K_VCS_SHORTEN_LENGTH]//\%/%%}${_POWERLEVEL9K_VCS_SHORTEN_DELIMITER} 
				if [[ $_POWERLEVEL9K_VCS_SHORTEN_STRATEGY == truncate_middle ]]
				then
					_p9k_vcs_style $state BRANCH
					branch+=${_p9k__ret}${VCS_STATUS_LOCAL_BRANCH[-_POWERLEVEL9K_VCS_SHORTEN_LENGTH,-1]//\%/%%} 
				fi
			else
				branch+=${VCS_STATUS_LOCAL_BRANCH//\%/%%} 
			fi
			_$0_fmt BRANCH $branch
		fi
		if [[ $_POWERLEVEL9K_VCS_HIDE_TAGS == 0 && -n $VCS_STATUS_TAG ]]
		then
			_p9k_get_icon prompt_vcs_$state VCS_TAG_ICON
			_$0_fmt TAG " $_p9k__ret${VCS_STATUS_TAG//\%/%%}"
		fi
		if [[ -n $VCS_STATUS_ACTION ]]
		then
			_$0_fmt ACTION " | ${VCS_STATUS_ACTION//\%/%%}"
		else
			if [[ -n $VCS_STATUS_REMOTE_BRANCH && $VCS_STATUS_LOCAL_BRANCH != $VCS_STATUS_REMOTE_BRANCH ]]
			then
				_p9k_get_icon prompt_vcs_$state VCS_REMOTE_BRANCH_ICON
				_$0_fmt REMOTE_BRANCH " $_p9k__ret${VCS_STATUS_REMOTE_BRANCH//\%/%%}"
			fi
			if [[ $VCS_STATUS_HAS_STAGED == 1 || $VCS_STATUS_HAS_UNSTAGED == 1 || $VCS_STATUS_HAS_UNTRACKED == 1 ]]
			then
				_p9k_get_icon prompt_vcs_$state VCS_DIRTY_ICON
				_$0_fmt DIRTY "$_p9k__ret"
				if [[ $VCS_STATUS_HAS_STAGED == 1 ]]
				then
					_p9k_get_icon prompt_vcs_$state VCS_STAGED_ICON
					(( _POWERLEVEL9K_VCS_STAGED_MAX_NUM != 1 )) && _p9k__ret+=$VCS_STATUS_NUM_STAGED 
					_$0_fmt STAGED " $_p9k__ret"
				fi
				if [[ $VCS_STATUS_HAS_UNSTAGED == 1 ]]
				then
					_p9k_get_icon prompt_vcs_$state VCS_UNSTAGED_ICON
					(( _POWERLEVEL9K_VCS_UNSTAGED_MAX_NUM != 1 )) && _p9k__ret+=$VCS_STATUS_NUM_UNSTAGED 
					_$0_fmt UNSTAGED " $_p9k__ret"
				fi
				if [[ $VCS_STATUS_HAS_UNTRACKED == 1 ]]
				then
					_p9k_get_icon prompt_vcs_$state VCS_UNTRACKED_ICON
					(( _POWERLEVEL9K_VCS_UNTRACKED_MAX_NUM != 1 )) && _p9k__ret+=$VCS_STATUS_NUM_UNTRACKED 
					_$0_fmt UNTRACKED " $_p9k__ret"
				fi
			fi
			if [[ $VCS_STATUS_COMMITS_BEHIND -gt 0 ]]
			then
				_p9k_get_icon prompt_vcs_$state VCS_INCOMING_CHANGES_ICON
				(( _POWERLEVEL9K_VCS_COMMITS_BEHIND_MAX_NUM != 1 )) && _p9k__ret+=$VCS_STATUS_COMMITS_BEHIND 
				_$0_fmt INCOMING_CHANGES " $_p9k__ret"
			fi
			if [[ $VCS_STATUS_COMMITS_AHEAD -gt 0 ]]
			then
				_p9k_get_icon prompt_vcs_$state VCS_OUTGOING_CHANGES_ICON
				(( _POWERLEVEL9K_VCS_COMMITS_AHEAD_MAX_NUM != 1 )) && _p9k__ret+=$VCS_STATUS_COMMITS_AHEAD 
				_$0_fmt OUTGOING_CHANGES " $_p9k__ret"
			fi
			if [[ $VCS_STATUS_STASHES -gt 0 ]]
			then
				_p9k_get_icon prompt_vcs_$state VCS_STASH_ICON
				_$0_fmt STASH " $_p9k__ret$VCS_STATUS_STASHES"
			fi
		fi
		_p9k_cache_ephemeral_set "prompt_vcs_$state" "${__p9k_vcs_states[$state]}" "$_p9k_color1" "$icon" 0 '' "$content"
	fi
	_p9k_prompt_segment "$_p9k__cache_val[@]"
	return 0
}
_p9k_vcs_resume () {
	eval "$__p9k_intro"
	_p9k_maybe_ignore_git_repo
	if [[ $VCS_STATUS_RESULT == ok-async ]]
	then
		local latency=$((EPOCHREALTIME - _p9k__gitstatus_start_time)) 
		if (( latency > _POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS ))
		then
			_p9k_git_slow[${${_p9k__git_dir:+GIT_DIR:$_p9k__git_dir}:-$VCS_STATUS_WORKDIR}]=1 
		elif (( $1 && latency < 0.8 * _POWERLEVEL9K_VCS_MAX_SYNC_LATENCY_SECONDS ))
		then
			_p9k_git_slow[${${_p9k__git_dir:+GIT_DIR:$_p9k__git_dir}:-$VCS_STATUS_WORKDIR}]=0 
		fi
		_p9k_vcs_status_save
	fi
	if [[ -z $_p9k__gitstatus_next_dir ]]
	then
		unset _p9k__gitstatus_next_dir
		case $VCS_STATUS_RESULT in
			(norepo-async) (( $1 )) && _p9k_vcs_status_purge $_p9k__cwd_a ;;
			(ok-async) (( $1 )) || _p9k__gitstatus_next_dir=$_p9k__cwd_a  ;;
		esac
	fi
	if [[ -n $_p9k__gitstatus_next_dir ]]
	then
		_p9k__git_dir=$GIT_DIR 
		if ! gitstatus_query_p9k_ -d $_p9k__gitstatus_next_dir -t 0 -c '_p9k_vcs_resume 1' POWERLEVEL9K
		then
			unset _p9k__gitstatus_next_dir
			unset VCS_STATUS_RESULT
		else
			_p9k_maybe_ignore_git_repo
			case $VCS_STATUS_RESULT in
				(tout) _p9k__gitstatus_next_dir='' 
					_p9k__gitstatus_start_time=$EPOCHREALTIME  ;;
				(norepo-sync) _p9k_vcs_status_purge $_p9k__gitstatus_next_dir
					unset _p9k__gitstatus_next_dir ;;
				(ok-sync) _p9k_vcs_status_save
					unset _p9k__gitstatus_next_dir ;;
			esac
		fi
	fi
	if (( _p9k_vcs_index && $+GITSTATUS_DAEMON_PID_POWERLEVEL9K ))
	then
		local _p9k__prompt _p9k__prompt_side=$_p9k_vcs_side _p9k__segment_name=vcs 
		local -i _p9k__has_upglob _p9k__segment_index=_p9k_vcs_index _p9k__line_index=_p9k_vcs_line_index 
		_p9k_vcs_render
		typeset -g _p9k__vcs=$_p9k__prompt 
	else
		_p9k__refresh_reason=gitstatus 
		_p9k_set_prompt
		_p9k__refresh_reason='' 
	fi
	_p9k_reset_prompt
}
_p9k_vcs_status_for_dir () {
	if [[ -n $GIT_DIR ]]
	then
		_p9k__ret=$_p9k__gitstatus_last[GIT_DIR:$GIT_DIR] 
		[[ -n $_p9k__ret ]]
	else
		local dir=$_p9k__cwd_a 
		while true
		do
			_p9k__ret=$_p9k__gitstatus_last[$dir] 
			[[ -n $_p9k__ret ]] && return 0
			[[ $dir == (/|.) ]] && return 1
			dir=${dir:h} 
		done
	fi
}
_p9k_vcs_status_purge () {
	if [[ -n $_p9k__git_dir ]]
	then
		_p9k__gitstatus_last[GIT_DIR:$_p9k__git_dir]="" 
	else
		local dir=$1 
		while true
		do
			_p9k__gitstatus_last[$dir]="" 
			_p9k_git_slow[$dir]="" 
			[[ $dir == (/|.) ]] && break
			dir=${dir:h} 
		done
	fi
}
_p9k_vcs_status_restore () {
	for VCS_STATUS_COMMIT VCS_STATUS_LOCAL_BRANCH VCS_STATUS_REMOTE_BRANCH VCS_STATUS_REMOTE_NAME VCS_STATUS_REMOTE_URL VCS_STATUS_ACTION VCS_STATUS_INDEX_SIZE VCS_STATUS_NUM_STAGED VCS_STATUS_NUM_UNSTAGED VCS_STATUS_NUM_CONFLICTED VCS_STATUS_NUM_UNTRACKED VCS_STATUS_HAS_STAGED VCS_STATUS_HAS_UNSTAGED VCS_STATUS_HAS_CONFLICTED VCS_STATUS_HAS_UNTRACKED VCS_STATUS_COMMITS_AHEAD VCS_STATUS_COMMITS_BEHIND VCS_STATUS_STASHES VCS_STATUS_TAG VCS_STATUS_NUM_UNSTAGED_DELETED VCS_STATUS_NUM_STAGED_NEW VCS_STATUS_NUM_STAGED_DELETED VCS_STATUS_PUSH_REMOTE_NAME VCS_STATUS_PUSH_REMOTE_URL VCS_STATUS_PUSH_COMMITS_AHEAD VCS_STATUS_PUSH_COMMITS_BEHIND VCS_STATUS_NUM_SKIP_WORKTREE VCS_STATUS_NUM_ASSUME_UNCHANGED in "${(@0)1}"
	do
		
	done
}
_p9k_vcs_status_save () {
	local z=$'\0' 
	_p9k__gitstatus_last[${${_p9k__git_dir:+GIT_DIR:$_p9k__git_dir}:-$VCS_STATUS_WORKDIR}]=$VCS_STATUS_COMMIT$z$VCS_STATUS_LOCAL_BRANCH$z$VCS_STATUS_REMOTE_BRANCH$z$VCS_STATUS_REMOTE_NAME$z$VCS_STATUS_REMOTE_URL$z$VCS_STATUS_ACTION$z$VCS_STATUS_INDEX_SIZE$z$VCS_STATUS_NUM_STAGED$z$VCS_STATUS_NUM_UNSTAGED$z$VCS_STATUS_NUM_CONFLICTED$z$VCS_STATUS_NUM_UNTRACKED$z$VCS_STATUS_HAS_STAGED$z$VCS_STATUS_HAS_UNSTAGED$z$VCS_STATUS_HAS_CONFLICTED$z$VCS_STATUS_HAS_UNTRACKED$z$VCS_STATUS_COMMITS_AHEAD$z$VCS_STATUS_COMMITS_BEHIND$z$VCS_STATUS_STASHES$z$VCS_STATUS_TAG$z$VCS_STATUS_NUM_UNSTAGED_DELETED$z$VCS_STATUS_NUM_STAGED_NEW$z$VCS_STATUS_NUM_STAGED_DELETED$z$VCS_STATUS_PUSH_REMOTE_NAME$z$VCS_STATUS_PUSH_REMOTE_URL$z$VCS_STATUS_PUSH_COMMITS_AHEAD$z$VCS_STATUS_PUSH_COMMITS_BEHIND$z$VCS_STATUS_NUM_SKIP_WORKTREE$z$VCS_STATUS_NUM_ASSUME_UNCHANGED 
}
_p9k_vcs_style () {
	local key="$0 ${(pj:\0:)*}" 
	_p9k__ret=$_p9k_cache[$key] 
	if [[ -n $_p9k__ret ]]
	then
		_p9k__ret[-1,-1]='' 
	else
		local style=%b 
		_p9k_color prompt_vcs_$1 BACKGROUND "${__p9k_vcs_states[$1]}"
		_p9k_background $_p9k__ret
		style+=$_p9k__ret 
		local var=_POWERLEVEL9K_VCS_${1}_${2}FORMAT_FOREGROUND 
		if (( $+parameters[$var] ))
		then
			_p9k_translate_color "${(P)var}"
		else
			var=_POWERLEVEL9K_VCS_${2}FORMAT_FOREGROUND 
			if (( $+parameters[$var] ))
			then
				_p9k_translate_color "${(P)var}"
			else
				_p9k_color prompt_vcs_$1 FOREGROUND "$_p9k_color1"
			fi
		fi
		_p9k_foreground $_p9k__ret
		_p9k__ret=$style$_p9k__ret 
		_p9k_cache[$key]=${_p9k__ret}. 
	fi
}
_p9k_vpn_ip_render () {
	local _p9k__segment_name=vpn_ip _p9k__prompt_side ip 
	local -i _p9k__has_upglob _p9k__segment_index
	for _p9k__prompt_side _p9k__line_index _p9k__segment_index in $_p9k__vpn_ip_segments
	do
		local _p9k__prompt= 
		for ip in $_p9k__vpn_ip_ips
		do
			_p9k_prompt_segment prompt_vpn_ip "cyan" "$_p9k_color1" 'VPN_ICON' 0 '' $ip
		done
		typeset -g _p9k__vpn_ip_$_p9k__prompt_side$_p9k__segment_index=$_p9k__prompt
	done
}
_p9k_widget () {
	local f=${widgets[._p9k_orig_$1]:-} 
	local -i res
	[[ -z $f ]] || {
		[[ $f == user:-z4h-* ]] && {
			"${f#user:}" "${@:2}"
			res=$? 
		} || {
			zle ._p9k_orig_$1 -- "${@:2}"
			res=$? 
		}
	}
	(( ! __p9k_enabled )) || [[ $CONTEXT != start ]] || _p9k_widget_hook "$@"
	return res
}
_p9k_widget_hook () {
	_p9k_deschedule_redraw
	if (( ${+functions[p10k-on-post-widget]} || ${#_p9k_show_on_command} ))
	then
		local -a P9K_COMMANDS
		if [[ "$_p9k__last_buffer" == "$PREBUFFER$BUFFER" ]]
		then
			P9K_COMMANDS=(${_p9k__last_commands[@]}) 
		else
			_p9k__last_buffer="$PREBUFFER$BUFFER" 
			if [[ -n "$_p9k__last_buffer" ]]
			then
				_p9k_parse_buffer "$_p9k__last_buffer" $_POWERLEVEL9K_COMMANDS_MAX_TOKEN_COUNT
			fi
			_p9k__last_commands=(${P9K_COMMANDS[@]}) 
		fi
	fi
	eval "$__p9k_intro"
	(( _p9k__restore_prompt_fd )) && _p9k_restore_prompt $_p9k__restore_prompt_fd
	if [[ $1 == (clear-screen|z4h-clear-screen-*-top) ]]
	then
		P9K_TTY=new 
		_p9k__expanded=0 
		_p9k_reset_prompt
	fi
	__p9k_reset_state=1 
	_p9k_check_visual_mode
	local pat idx var
	for pat idx var in $_p9k_show_on_command
	do
		if (( $P9K_COMMANDS[(I)$pat] ))
		then
			_p9k_display_segment $idx $var show
		else
			_p9k_display_segment $idx $var hide
		fi
	done
	(( $+functions[p10k-on-post-widget] )) && p10k-on-post-widget "${@:2}"
	(( $+functions[_p9k_on_widget_$1] )) && _p9k_on_widget_$1
	(( __p9k_reset_state == 2 )) && _p9k_reset_prompt
	__p9k_reset_state=0 
}
_p9k_widget_send-break () {
	(( ! __p9k_enabled )) || [[ $CONTEXT != start ]] || {
		_p9k_widget_hook send-break "$@"
	}
	local f=${widgets[._p9k_orig_send-break]:-} 
	[[ -z $f ]] || zle ._p9k_orig_send-break -- "$@"
}
_p9k_widget_zle-line-pre-redraw-impl () {
	(( __p9k_enabled )) && [[ $CONTEXT == start ]] || return 0
	! (( ${+functions[p10k-on-post-widget]} || ${#_p9k_show_on_command} || _p9k__restore_prompt_fd || _p9k__redraw_fd )) && [[ ${KEYMAP:-} != vicmd ]] && return
	(( PENDING || KEYS_QUEUED_COUNT )) && {
		(( _p9k__redraw_fd )) || {
			sysopen -o cloexec -ru _p9k__redraw_fd /dev/null
			zle -F $_p9k__redraw_fd _p9k_redraw
		}
		return
	}
	_p9k_widget_hook zle-line-pre-redraw
}
_p9k_worker_cleanup () {
	emulate -L zsh
	[[ $_p9k__worker_shell_pid == $sysparams[pid] ]] && _p9k_worker_stop
	return 0
}
_p9k_worker_invoke () {
	[[ -n $_p9k__worker_resp_fd ]] || return
	local req=$1$'\x1f'$2$'\x1e' 
	if [[ -n $_p9k__worker_req_fd && $+_p9k__worker_request_map[$1] == 0 ]]
	then
		_p9k__worker_request_map[$1]= 
		print -rnu $_p9k__worker_req_fd -- $req
	else
		_p9k__worker_request_map[$1]=$req 
	fi
}
_p9k_worker_main () {
	mkfifo -- $_p9k__worker_file_prefix.fifo || return
	echo -nE - s$_p9k_worker_pgid$'\x1e' || return
	exec < $_p9k__worker_file_prefix.fifo || return
	zf_rm -- $_p9k__worker_file_prefix.fifo || return
	local -i reset
	local req fd
	local -a ready
	local _p9k_worker_request_id
	local -A _p9k_worker_fds
	local -A _p9k_worker_inflight
	_p9k_worker_reply () {
		print -nr -- e${(pj:\n:)@}$'\x1e' || kill -- -$_p9k_worker_pgid
	}
	_p9k_worker_async () {
		local fd async=$1 
		sysopen -r -o cloexec -u fd <(() { eval $async; } && print -n '\x1e') || return
		(( ++_p9k_worker_inflight[$_p9k_worker_request_id] ))
		_p9k_worker_fds[$fd]=$_p9k_worker_request_id$'\x1f'$2 
	}
	trap '' PIPE
	{
		while zselect -a ready 0 ${(k)_p9k_worker_fds}
		do
			[[ $ready[1] == -r ]] || return
			for fd in ${ready:1}
			do
				if [[ $fd == 0 ]]
				then
					local buf= 
					[[ -t 0 ]]
					if sysread -t 0 'buf[$#buf+1]'
					then
						while [[ $buf != *$'\x1e' ]]
						do
							sysread 'buf[$#buf+1]' || return
						done
					else
						(( $? == 4 )) || return
					fi
					for req in ${(ps:\x1e:)buf}
					do
						_p9k_worker_request_id=${req%%$'\x1f'*} 
						() {
							eval $req[$#_p9k_worker_request_id+2,-1]
						}
						(( $+_p9k_worker_inflight[$_p9k_worker_request_id] )) && continue
						print -rn -- d$_p9k_worker_request_id$'\x1e' || return
					done
				else
					local REPLY= 
					while true
					do
						if sysread -i $fd 'REPLY[$#REPLY+1]'
						then
							[[ $REPLY == *$'\x1e' ]] || continue
						else
							(( $? == 5 )) || return
							break
						fi
					done
					local cb=$_p9k_worker_fds[$fd] 
					_p9k_worker_request_id=${cb%%$'\x1f'*} 
					unset "_p9k_worker_fds[$fd]"
					exec {fd}>&-
					if [[ $REPLY == *$'\x1e' ]]
					then
						REPLY[-1]="" 
						() {
							eval $cb[$#_p9k_worker_request_id+2,-1]
						}
					fi
					if (( --_p9k_worker_inflight[$_p9k_worker_request_id] == 0 ))
					then
						unset "_p9k_worker_inflight[$_p9k_worker_request_id]"
						print -rn -- d$_p9k_worker_request_id$'\x1e' || return
					fi
				fi
			done
		done
	} always {
		kill -- -$_p9k_worker_pgid
	}
}
_p9k_worker_receive () {
	eval "$__p9k_intro"
	[[ -z $_p9k__worker_resp_fd ]] && return
	{
		(( $# <= 1 )) || return
		local buf resp
		[[ -t $_p9k__worker_resp_fd ]]
		if sysread -i $_p9k__worker_resp_fd -t 0 'buf[$#buf+1]'
		then
			while [[ $buf == *[^$'\x05\x1e']$'\x05'# ]]
			do
				sysread -i $_p9k__worker_resp_fd 'buf[$#buf+1]' || return
			done
		else
			(( $? == 4 )) || return
		fi
		local -i reset max_reset
		for resp in ${(ps:\x1e:)${buf//$'\x05'}}
		do
			local arg=$resp[2,-1] 
			case $resp[1] in
				(d) local req=$_p9k__worker_request_map[$arg] 
					if [[ -n $req ]]
					then
						_p9k__worker_request_map[$arg]= 
						print -rnu $_p9k__worker_req_fd -- $req || return
					else
						unset "_p9k__worker_request_map[$arg]"
					fi ;;
				(e) () {
						eval $arg
					}
					(( reset > max_reset )) && max_reset=reset  ;;
				(s) [[ -z $_p9k__worker_req_fd ]] || return
					[[ $arg == <1-> ]] || return
					_p9k__worker_pid=$arg 
					sysopen -w -o cloexec -u _p9k__worker_req_fd $_p9k__worker_file_prefix.fifo || return
					local req= 
					for req in $_p9k__worker_request_map
					do
						print -rnu $_p9k__worker_req_fd -- $req || return
					done
					_p9k__worker_request_map=({${(k)^_p9k__worker_request_map},''})  ;;
				(*) return 1 ;;
			esac
		done
		if (( max_reset == 2 ))
		then
			_p9k__refresh_reason=worker 
			_p9k_set_prompt
			_p9k__refresh_reason='' 
		fi
		(( max_reset )) && _p9k_reset_prompt
		return 0
	} always {
		(( $? )) && _p9k_worker_stop
	}
}
_p9k_worker_start () {
	setopt monitor || return
	{
		[[ -n $_p9k__worker_resp_fd ]] && return
		if [[ -n "$TMPDIR" && ( ( -d "$TMPDIR" && -w "$TMPDIR" ) || ! ( -d /tmp && -w /tmp ) ) ]]
		then
			local tmpdir=$TMPDIR 
		else
			local tmpdir=/tmp 
		fi
		_p9k__worker_file_prefix=$tmpdir/p10k.worker.$EUID.$sysparams[pid].$EPOCHSECONDS 
		sysopen -r -o cloexec -u _p9k__worker_resp_fd <(
      exec 0</dev/null
      if [[ -n $_POWERLEVEL9K_WORKER_LOG_LEVEL ]]; then
        exec 2>$_p9k__worker_file_prefix.log
        setopt xtrace
      else
        exec 2>/dev/null
      fi
      builtin cd -q /                    || return
      zmodload zsh/zselect               || return
      ! { zselect -t0 || (( $? != 1 )) } || return
      local _p9k_worker_pgid=$sysparams[pid]
      _p9k_worker_main &
      {
        trap '' PIPE
        while syswrite $'\x05'; do zselect -t 1000; done
        zf_rm -f $_p9k__worker_file_prefix.fifo
        kill -- -$_p9k_worker_pgid
      } &
      exec =true) || return
		_p9k__worker_pid=$sysparams[procsubstpid] 
		zle -F $_p9k__worker_resp_fd _p9k_worker_receive
		_p9k__worker_shell_pid=$sysparams[pid] 
		add-zsh-hook zshexit _p9k_worker_cleanup
	} always {
		(( $? )) && _p9k_worker_stop
	}
}
_p9k_worker_stop () {
	emulate -L zsh
	add-zsh-hook -D zshexit _p9k_worker_cleanup
	[[ -n $_p9k__worker_resp_fd ]] && zle -F $_p9k__worker_resp_fd
	[[ -n $_p9k__worker_resp_fd ]] && exec {_p9k__worker_resp_fd}>&-
	[[ -n $_p9k__worker_req_fd ]] && exec {_p9k__worker_req_fd}>&-
	[[ -n $_p9k__worker_pid ]] && kill -- -$_p9k__worker_pid 2> /dev/null
	[[ -n $_p9k__worker_file_prefix ]] && zf_rm -f -- $_p9k__worker_file_prefix.fifo
	_p9k__worker_pid= 
	_p9k__worker_req_fd= 
	_p9k__worker_resp_fd= 
	_p9k__worker_shell_pid= 
	_p9k__worker_request_map=() 
	return 0
}
_p9k_wrap_widgets () {
	(( __p9k_widgets_wrapped )) && return
	typeset -gir __p9k_widgets_wrapped=1 
	local -a widget_list
	if [[ $ZSH_VERSION == (5.<3->*|<6->.*) ]]
	then
		local -aU widget_list=(zle-line-pre-redraw zle-line-init zle-line-finish zle-keymap-select overwrite-mode vi-replace visual-mode visual-line-mode deactivate-region clear-screen z4h-clear-screen-soft-top z4h-clear-screen-hard-top send-break $_POWERLEVEL9K_HOOK_WIDGETS) 
	else
		if [[ -n "$TMPDIR" && ( ( -d "$TMPDIR" && -w "$TMPDIR" ) || ! ( -d /tmp && -w /tmp ) ) ]]
		then
			local tmpdir=$TMPDIR 
		else
			local tmpdir=/tmp 
		fi
		local keymap tmp=$tmpdir/p10k.bindings.$sysparams[pid] 
		{
			for keymap in $keymaps
			do
				bindkey -M $keymap
			done > $tmp
			local -aU widget_list=(zle-isearch-exit zle-isearch-update zle-line-init zle-line-finish zle-history-line-set zle-keymap-select send-break $_POWERLEVEL9K_HOOK_WIDGETS ${${${(f)"$(<$tmp)"}##* }:#(*\"|.*)}) 
		} always {
			zf_rm -f -- $tmp
		}
	fi
	local widget
	for widget in $widget_list
	do
		if (( ! $+functions[_p9k_widget_$widget] ))
		then
			functions[_p9k_widget_$widget]='_p9k_widget '${(q)widget}' "$@"' 
		fi
		if [[ $widget == zle-* && $widgets[$widget] == user:azhw:* && -n $functions[add-zle-hook-widget] ]]
		then
			add-zle-hook-widget $widget _p9k_widget_$widget
		else
			zle -A $widget ._p9k_orig_$widget
			zle -N $widget _p9k_widget_$widget
		fi
	done 2> /dev/null
	case ${widgets[._p9k_orig_zle-line-pre-redraw]:-} in
		(user:-z4h-zle-line-pre-redraw) _p9k_widget_zle-line-pre-redraw () {
				-z4h-zle-line-pre-redraw "$@"
				_p9k_widget_zle-line-pre-redraw-impl
			} ;;
		(?*) _p9k_widget_zle-line-pre-redraw () {
				zle ._p9k_orig_zle-line-pre-redraw -- "$@"
				local -i res=$? 
				_p9k_widget_zle-line-pre-redraw-impl
				return res
			} ;;
		('') _p9k_widget_zle-line-pre-redraw () {
				_p9k_widget_zle-line-pre-redraw-impl
			} ;;
	esac
}
_pack () {
	# undefined
	builtin autoload -XUz
}
_pandoc () {
	# undefined
	builtin autoload -XUz
}
_parameter () {
	# undefined
	builtin autoload -XUz
}
_parameters () {
	# undefined
	builtin autoload -XUz
}
_paste () {
	# undefined
	builtin autoload -XUz
}
_patch () {
	# undefined
	builtin autoload -XUz
}
_patchutils () {
	# undefined
	builtin autoload -XUz
}
_path_commands () {
	# undefined
	builtin autoload -XUz
}
_path_files () {
	# undefined
	builtin autoload -XUz
}
_pax () {
	# undefined
	builtin autoload -XUz
}
_pbcopy () {
	# undefined
	builtin autoload -XUz
}
_pbm () {
	# undefined
	builtin autoload -XUz
}
_pbuilder () {
	# undefined
	builtin autoload -XUz
}
_pdf () {
	# undefined
	builtin autoload -XUz
}
_pdftk () {
	# undefined
	builtin autoload -XUz
}
_perf () {
	# undefined
	builtin autoload -XUz
}
_perforce () {
	# undefined
	builtin autoload -XUz
}
_perl () {
	# undefined
	builtin autoload -XUz
}
_perl_basepods () {
	# undefined
	builtin autoload -XUz
}
_perl_modules () {
	# undefined
	builtin autoload -XUz
}
_perldoc () {
	# undefined
	builtin autoload -XUz
}
_pfctl () {
	# undefined
	builtin autoload -XUz
}
_pfexec () {
	# undefined
	builtin autoload -XUz
}
_pgids () {
	# undefined
	builtin autoload -XUz
}
_pgrep () {
	# undefined
	builtin autoload -XUz
}
_php () {
	# undefined
	builtin autoload -XUz
}
_physical_volumes () {
	# undefined
	builtin autoload -XUz
}
_pick_variant () {
	# undefined
	builtin autoload -XUz
}
_picocom () {
	# undefined
	builtin autoload -XUz
}
_pidof () {
	# undefined
	builtin autoload -XUz
}
_pids () {
	# undefined
	builtin autoload -XUz
}
_pine () {
	# undefined
	builtin autoload -XUz
}
_ping () {
	# undefined
	builtin autoload -XUz
}
_pip () {
	# undefined
	builtin autoload -XUz
}
_piuparts () {
	# undefined
	builtin autoload -XUz
}
_pkg-config () {
	# undefined
	builtin autoload -XUz
}
_pkg5 () {
	# undefined
	builtin autoload -XUz
}
_pkg_instance () {
	# undefined
	builtin autoload -XUz
}
_pkgadd () {
	# undefined
	builtin autoload -XUz
}
_pkgin () {
	# undefined
	builtin autoload -XUz
}
_pkginfo () {
	# undefined
	builtin autoload -XUz
}
_pkgrm () {
	# undefined
	builtin autoload -XUz
}
_pkgtool () {
	# undefined
	builtin autoload -XUz
}
_playerctl () {
	# undefined
	builtin autoload -XUz
}
_plutil () {
	# undefined
	builtin autoload -XUz
}
_pmap () {
	# undefined
	builtin autoload -XUz
}
_pon () {
	# undefined
	builtin autoload -XUz
}
_portaudit () {
	# undefined
	builtin autoload -XUz
}
_portlint () {
	# undefined
	builtin autoload -XUz
}
_portmaster () {
	# undefined
	builtin autoload -XUz
}
_ports () {
	# undefined
	builtin autoload -XUz
}
_portsnap () {
	# undefined
	builtin autoload -XUz
}
_postfix () {
	# undefined
	builtin autoload -XUz
}
_postgresql () {
	# undefined
	builtin autoload -XUz
}
_postscript () {
	# undefined
	builtin autoload -XUz
}
_powerd () {
	# undefined
	builtin autoload -XUz
}
_pr () {
	# undefined
	builtin autoload -XUz
}
_precommand () {
	# undefined
	builtin autoload -XUz
}
_prefix () {
	# undefined
	builtin autoload -XUz
}
_print () {
	# undefined
	builtin autoload -XUz
}
_printenv () {
	# undefined
	builtin autoload -XUz
}
_printers () {
	# undefined
	builtin autoload -XUz
}
_process_names () {
	# undefined
	builtin autoload -XUz
}
_procstat () {
	# undefined
	builtin autoload -XUz
}
_prompt () {
	# undefined
	builtin autoload -XUz
}
_prove () {
	# undefined
	builtin autoload -XUz
}
_prstat () {
	# undefined
	builtin autoload -XUz
}
_ps () {
	# undefined
	builtin autoload -XUz
}
_ps1234 () {
	# undefined
	builtin autoload -XUz
}
_pscp () {
	# undefined
	builtin autoload -XUz
}
_pspdf () {
	# undefined
	builtin autoload -XUz
}
_psutils () {
	# undefined
	builtin autoload -XUz
}
_ptree () {
	# undefined
	builtin autoload -XUz
}
_ptx () {
	# undefined
	builtin autoload -XUz
}
_pump () {
	# undefined
	builtin autoload -XUz
}
_putclip () {
	# undefined
	builtin autoload -XUz
}
_pv () {
	# undefined
	builtin autoload -XUz
}
_pwgen () {
	# undefined
	builtin autoload -XUz
}
_pydoc () {
	# undefined
	builtin autoload -XUz
}
_python () {
	# undefined
	builtin autoload -XUz
}
_python_modules () {
	# undefined
	builtin autoload -XUz
}
_qdbus () {
	# undefined
	builtin autoload -XUz
}
_qemu () {
	# undefined
	builtin autoload -XUz
}
_qiv () {
	# undefined
	builtin autoload -XUz
}
_qtplay () {
	# undefined
	builtin autoload -XUz
}
_quilt () {
	# undefined
	builtin autoload -XUz
}
_rake () {
	# undefined
	builtin autoload -XUz
}
_ranlib () {
	# undefined
	builtin autoload -XUz
}
_rar () {
	# undefined
	builtin autoload -XUz
}
_rcctl () {
	# undefined
	builtin autoload -XUz
}
_rclone () {
	# undefined
	builtin autoload -XUz
}
_rcs () {
	# undefined
	builtin autoload -XUz
}
_rdesktop () {
	# undefined
	builtin autoload -XUz
}
_read () {
	# undefined
	builtin autoload -XUz
}
_read_comp () {
	# undefined
	builtin autoload -XUz
}
_readelf () {
	# undefined
	builtin autoload -XUz
}
_readlink () {
	# undefined
	builtin autoload -XUz
}
_readshortcut () {
	# undefined
	builtin autoload -XUz
}
_rebootin () {
	# undefined
	builtin autoload -XUz
}
_redirect () {
	# undefined
	builtin autoload -XUz
}
_regex_arguments () {
	# undefined
	builtin autoload -XUz
}
_regex_words () {
	# undefined
	builtin autoload -XUz
}
_remote_files () {
	# undefined
	builtin autoload -XUz
}
_renice () {
	# undefined
	builtin autoload -XUz
}
_reprepro () {
	# undefined
	builtin autoload -XUz
}
_requested () {
	# undefined
	builtin autoload -XUz
}
_resolvectl () {
	# undefined
	builtin autoload -XUz
}
_retrieve_cache () {
	# undefined
	builtin autoload -XUz
}
_retrieve_mac_apps () {
	# undefined
	builtin autoload -XUz
}
_rg () {
	# undefined
	builtin autoload -XUz
}
_ri () {
	# undefined
	builtin autoload -XUz
}
_rlogin () {
	# undefined
	builtin autoload -XUz
}
_rm () {
	# undefined
	builtin autoload -XUz
}
_rmdir () {
	# undefined
	builtin autoload -XUz
}
_route () {
	# undefined
	builtin autoload -XUz
}
_routing_domains () {
	# undefined
	builtin autoload -XUz
}
_routing_tables () {
	# undefined
	builtin autoload -XUz
}
_rpm () {
	# undefined
	builtin autoload -XUz
}
_rrdtool () {
	# undefined
	builtin autoload -XUz
}
_rsync () {
	# undefined
	builtin autoload -XUz
}
_rubber () {
	# undefined
	builtin autoload -XUz
}
_ruby () {
	# undefined
	builtin autoload -XUz
}
_run-help () {
	# undefined
	builtin autoload -XUz
}
_run0 () {
	# undefined
	builtin autoload -XUz
}
_runit () {
	# undefined
	builtin autoload -XUz
}
_samba () {
	# undefined
	builtin autoload -XUz
}
_savecore () {
	# undefined
	builtin autoload -XUz
}
_say () {
	# undefined
	builtin autoload -XUz
}
_sbuild () {
	# undefined
	builtin autoload -XUz
}
_sc_usage () {
	# undefined
	builtin autoload -XUz
}
_sccs () {
	# undefined
	builtin autoload -XUz
}
_sched () {
	# undefined
	builtin autoload -XUz
}
_schedtool () {
	# undefined
	builtin autoload -XUz
}
_schroot () {
	# undefined
	builtin autoload -XUz
}
_scl () {
	# undefined
	builtin autoload -XUz
}
_scons () {
	# undefined
	builtin autoload -XUz
}
_screen () {
	# undefined
	builtin autoload -XUz
}
_script () {
	# undefined
	builtin autoload -XUz
}
_scselect () {
	# undefined
	builtin autoload -XUz
}
_scutil () {
	# undefined
	builtin autoload -XUz
}
_sd_bus_address () {
	# undefined
	builtin autoload -XUz
}
_sd_hosts_or_user_at_host () {
	# undefined
	builtin autoload -XUz
}
_sd_machines () {
	# undefined
	builtin autoload -XUz
}
_sd_outputmodes () {
	# undefined
	builtin autoload -XUz
}
_sd_unit_files () {
	# undefined
	builtin autoload -XUz
}
_seafile () {
	# undefined
	builtin autoload -XUz
}
_sed () {
	# undefined
	builtin autoload -XUz
}
_selinux_contexts () {
	# undefined
	builtin autoload -XUz
}
_selinux_roles () {
	# undefined
	builtin autoload -XUz
}
_selinux_types () {
	# undefined
	builtin autoload -XUz
}
_selinux_users () {
	# undefined
	builtin autoload -XUz
}
_sep_parts () {
	# undefined
	builtin autoload -XUz
}
_seq () {
	# undefined
	builtin autoload -XUz
}
_sequence () {
	# undefined
	builtin autoload -XUz
}
_service () {
	# undefined
	builtin autoload -XUz
}
_services () {
	# undefined
	builtin autoload -XUz
}
_set () {
	# undefined
	builtin autoload -XUz
}
_set_command () {
	# undefined
	builtin autoload -XUz
}
_setfacl () {
	# undefined
	builtin autoload -XUz
}
_setopt () {
	# undefined
	builtin autoload -XUz
}
_setpriv () {
	# undefined
	builtin autoload -XUz
}
_setsid () {
	# undefined
	builtin autoload -XUz
}
_setup () {
	# undefined
	builtin autoload -XUz
}
_setxkbmap () {
	# undefined
	builtin autoload -XUz
}
_sh () {
	# undefined
	builtin autoload -XUz
}
_shasum () {
	# undefined
	builtin autoload -XUz
}
_showmount () {
	# undefined
	builtin autoload -XUz
}
_shred () {
	# undefined
	builtin autoload -XUz
}
_shuf () {
	# undefined
	builtin autoload -XUz
}
_shutdown () {
	# undefined
	builtin autoload -XUz
}
_signals () {
	# undefined
	builtin autoload -XUz
}
_signify () {
	# undefined
	builtin autoload -XUz
}
_sisu () {
	# undefined
	builtin autoload -XUz
}
_slabtop () {
	# undefined
	builtin autoload -XUz
}
_slrn () {
	# undefined
	builtin autoload -XUz
}
_smartmontools () {
	# undefined
	builtin autoload -XUz
}
_smit () {
	# undefined
	builtin autoload -XUz
}
_snoop () {
	# undefined
	builtin autoload -XUz
}
_socket () {
	# undefined
	builtin autoload -XUz
}
_sockstat () {
	# undefined
	builtin autoload -XUz
}
_softwareupdate () {
	# undefined
	builtin autoload -XUz
}
_sort () {
	# undefined
	builtin autoload -XUz
}
_source () {
	# undefined
	builtin autoload -XUz
}
_spamassassin () {
	# undefined
	builtin autoload -XUz
}
_split () {
	# undefined
	builtin autoload -XUz
}
_sqlite () {
	# undefined
	builtin autoload -XUz
}
_sqsh () {
	# undefined
	builtin autoload -XUz
}
_ss () {
	# undefined
	builtin autoload -XUz
}
_ssh () {
	# undefined
	builtin autoload -XUz
}
_ssh_hosts () {
	# undefined
	builtin autoload -XUz
}
_sshfs () {
	# undefined
	builtin autoload -XUz
}
_starship () {
	# undefined
	builtin autoload -XUz
}
_stat () {
	# undefined
	builtin autoload -XUz
}
_stdbuf () {
	# undefined
	builtin autoload -XUz
}
_stgit () {
	# undefined
	builtin autoload -XUz
}
_store_cache () {
	# undefined
	builtin autoload -XUz
}
_stow () {
	# undefined
	builtin autoload -XUz
}
_strace () {
	# undefined
	builtin autoload -XUz
}
_strftime () {
	# undefined
	builtin autoload -XUz
}
_strings () {
	# undefined
	builtin autoload -XUz
}
_strip () {
	# undefined
	builtin autoload -XUz
}
_stty () {
	# undefined
	builtin autoload -XUz
}
_su () {
	# undefined
	builtin autoload -XUz
}
_sub_commands () {
	# undefined
	builtin autoload -XUz
}
_sublimetext () {
	# undefined
	builtin autoload -XUz
}
_subscript () {
	# undefined
	builtin autoload -XUz
}
_subversion () {
	# undefined
	builtin autoload -XUz
}
_sudo () {
	# undefined
	builtin autoload -XUz
}
_suffix_alias_files () {
	# undefined
	builtin autoload -XUz
}
_surfraw () {
	# undefined
	builtin autoload -XUz
}
_svcadm () {
	# undefined
	builtin autoload -XUz
}
_svccfg () {
	# undefined
	builtin autoload -XUz
}
_svcprop () {
	# undefined
	builtin autoload -XUz
}
_svcs () {
	# undefined
	builtin autoload -XUz
}
_svcs_fmri () {
	# undefined
	builtin autoload -XUz
}
_svn-buildpackage () {
	# undefined
	builtin autoload -XUz
}
_sw_vers () {
	# undefined
	builtin autoload -XUz
}
_swaks () {
	# undefined
	builtin autoload -XUz
}
_swanctl () {
	# undefined
	builtin autoload -XUz
}
_swift () {
	# undefined
	builtin autoload -XUz
}
_sys_calls () {
	# undefined
	builtin autoload -XUz
}
_sysclean () {
	# undefined
	builtin autoload -XUz
}
_sysctl () {
	# undefined
	builtin autoload -XUz
}
_sysmerge () {
	# undefined
	builtin autoload -XUz
}
_syspatch () {
	# undefined
	builtin autoload -XUz
}
_sysrc () {
	# undefined
	builtin autoload -XUz
}
_sysstat () {
	# undefined
	builtin autoload -XUz
}
_systat () {
	# undefined
	builtin autoload -XUz
}
_system_profiler () {
	# undefined
	builtin autoload -XUz
}
_systemctl () {
	# undefined
	builtin autoload -XUz
}
_systemd () {
	# undefined
	builtin autoload -XUz
}
_systemd-analyze () {
	# undefined
	builtin autoload -XUz
}
_systemd-delta () {
	# undefined
	builtin autoload -XUz
}
_systemd-inhibit () {
	# undefined
	builtin autoload -XUz
}
_systemd-nspawn () {
	# undefined
	builtin autoload -XUz
}
_systemd-path () {
	# undefined
	builtin autoload -XUz
}
_systemd-run () {
	# undefined
	builtin autoload -XUz
}
_systemd-tmpfiles () {
	# undefined
	builtin autoload -XUz
}
_sysupgrade () {
	# undefined
	builtin autoload -XUz
}
_tac () {
	# undefined
	builtin autoload -XUz
}
_tags () {
	# undefined
	builtin autoload -XUz
}
_tail () {
	# undefined
	builtin autoload -XUz
}
_tar () {
	# undefined
	builtin autoload -XUz
}
_tar_archive () {
	# undefined
	builtin autoload -XUz
}
_tardy () {
	# undefined
	builtin autoload -XUz
}
_tcpdump () {
	# undefined
	builtin autoload -XUz
}
_tcpsys () {
	# undefined
	builtin autoload -XUz
}
_tcptraceroute () {
	# undefined
	builtin autoload -XUz
}
_tee () {
	# undefined
	builtin autoload -XUz
}
_telnet () {
	# undefined
	builtin autoload -XUz
}
_terminals () {
	# undefined
	builtin autoload -XUz
}
_tex () {
	# undefined
	builtin autoload -XUz
}
_texi () {
	# undefined
	builtin autoload -XUz
}
_texinfo () {
	# undefined
	builtin autoload -XUz
}
_tidy () {
	# undefined
	builtin autoload -XUz
}
_tiff () {
	# undefined
	builtin autoload -XUz
}
_tilde () {
	# undefined
	builtin autoload -XUz
}
_tilde_files () {
	# undefined
	builtin autoload -XUz
}
_time_zone () {
	# undefined
	builtin autoload -XUz
}
_time_zone.orig () {
	# undefined
	builtin autoload -XUz
}
_timedatectl () {
	# undefined
	builtin autoload -XUz
}
_timeout () {
	# undefined
	builtin autoload -XUz
}
_tin () {
	# undefined
	builtin autoload -XUz
}
_tla () {
	# undefined
	builtin autoload -XUz
}
_tldr () {
	# undefined
	builtin autoload -XUz
}
_tload () {
	# undefined
	builtin autoload -XUz
}
_tlp () {
	# undefined
	builtin autoload -XUz
}
_tlp-radio-device () {
	# undefined
	builtin autoload -XUz
}
_tlp-rdw () {
	# undefined
	builtin autoload -XUz
}
_tlp-run-on () {
	# undefined
	builtin autoload -XUz
}
_tlp-stat () {
	# undefined
	builtin autoload -XUz
}
_tmux () {
	# undefined
	builtin autoload -XUz
}
_todo.sh () {
	# undefined
	builtin autoload -XUz
}
_toilet () {
	# undefined
	builtin autoload -XUz
}
_toolchain-source () {
	# undefined
	builtin autoload -XUz
}
_top () {
	# undefined
	builtin autoload -XUz
}
_topgit () {
	# undefined
	builtin autoload -XUz
}
_totd () {
	# undefined
	builtin autoload -XUz
}
_touch () {
	# undefined
	builtin autoload -XUz
}
_tpb () {
	# undefined
	builtin autoload -XUz
}
_tput () {
	# undefined
	builtin autoload -XUz
}
_tr () {
	# undefined
	builtin autoload -XUz
}
_tracepath () {
	# undefined
	builtin autoload -XUz
}
_transmission () {
	# undefined
	builtin autoload -XUz
}
_trap () {
	# undefined
	builtin autoload -XUz
}
_trash () {
	# undefined
	builtin autoload -XUz
}
_tree () {
	# undefined
	builtin autoload -XUz
}
_truncate () {
	# undefined
	builtin autoload -XUz
}
_truss () {
	# undefined
	builtin autoload -XUz
}
_tty () {
	# undefined
	builtin autoload -XUz
}
_ttyctl () {
	# undefined
	builtin autoload -XUz
}
_ttys () {
	# undefined
	builtin autoload -XUz
}
_tune2fs () {
	# undefined
	builtin autoload -XUz
}
_twidge () {
	# undefined
	builtin autoload -XUz
}
_twisted () {
	# undefined
	builtin autoload -XUz
}
_typeset () {
	# undefined
	builtin autoload -XUz
}
_udevadm () {
	# undefined
	builtin autoload -XUz
}
_udisks2 () {
	# undefined
	builtin autoload -XUz
}
_ulimit () {
	# undefined
	builtin autoload -XUz
}
_uml () {
	# undefined
	builtin autoload -XUz
}
_umountable () {
	# undefined
	builtin autoload -XUz
}
_unace () {
	# undefined
	builtin autoload -XUz
}
_uname () {
	# undefined
	builtin autoload -XUz
}
_unexpand () {
	# undefined
	builtin autoload -XUz
}
_unhash () {
	# undefined
	builtin autoload -XUz
}
_uniq () {
	# undefined
	builtin autoload -XUz
}
_unison () {
	# undefined
	builtin autoload -XUz
}
_units () {
	# undefined
	builtin autoload -XUz
}
_unshare () {
	# undefined
	builtin autoload -XUz
}
_update-alternatives () {
	# undefined
	builtin autoload -XUz
}
_update-rc.d () {
	# undefined
	builtin autoload -XUz
}
_uptime () {
	# undefined
	builtin autoload -XUz
}
_urls () {
	# undefined
	builtin autoload -XUz
}
_urpmi () {
	# undefined
	builtin autoload -XUz
}
_urxvt () {
	# undefined
	builtin autoload -XUz
}
_usbconfig () {
	# undefined
	builtin autoload -XUz
}
_uscan () {
	# undefined
	builtin autoload -XUz
}
_user_admin () {
	# undefined
	builtin autoload -XUz
}
_user_at_host () {
	# undefined
	builtin autoload -XUz
}
_user_expand () {
	# undefined
	builtin autoload -XUz
}
_user_math_func () {
	# undefined
	builtin autoload -XUz
}
_users () {
	# undefined
	builtin autoload -XUz
}
_users_on () {
	# undefined
	builtin autoload -XUz
}
_valgrind () {
	# undefined
	builtin autoload -XUz
}
_value () {
	# undefined
	builtin autoload -XUz
}
_values () {
	# undefined
	builtin autoload -XUz
}
_vared () {
	# undefined
	builtin autoload -XUz
}
_varlinkctl () {
	# undefined
	builtin autoload -XUz
}
_vars () {
	# undefined
	builtin autoload -XUz
}
_vcs_info () {
	# undefined
	builtin autoload -XUz
}
_vcs_info_hooks () {
	# undefined
	builtin autoload -XUz
}
_vi () {
	# undefined
	builtin autoload -XUz
}
_vim () {
	# undefined
	builtin autoload -XUz
}
_vim-addons () {
	# undefined
	builtin autoload -XUz
}
_visudo () {
	# undefined
	builtin autoload -XUz
}
_vmctl () {
	# undefined
	builtin autoload -XUz
}
_vmstat () {
	# undefined
	builtin autoload -XUz
}
_vnc () {
	# undefined
	builtin autoload -XUz
}
_volume_groups () {
	# undefined
	builtin autoload -XUz
}
_vorbis () {
	# undefined
	builtin autoload -XUz
}
_vpnc () {
	# undefined
	builtin autoload -XUz
}
_vserver () {
	# undefined
	builtin autoload -XUz
}
_w () {
	# undefined
	builtin autoload -XUz
}
_w3m () {
	# undefined
	builtin autoload -XUz
}
_wait () {
	# undefined
	builtin autoload -XUz
}
_wajig () {
	# undefined
	builtin autoload -XUz
}
_wakeup_capable_devices () {
	# undefined
	builtin autoload -XUz
}
_wanna-build () {
	# undefined
	builtin autoload -XUz
}
_wanted () {
	# undefined
	builtin autoload -XUz
}
_watch () {
	# undefined
	builtin autoload -XUz
}
_watch-snoop () {
	# undefined
	builtin autoload -XUz
}
_wc () {
	# undefined
	builtin autoload -XUz
}
_webbrowser () {
	# undefined
	builtin autoload -XUz
}
_wget () {
	# undefined
	builtin autoload -XUz
}
_whereis () {
	# undefined
	builtin autoload -XUz
}
_which () {
	# undefined
	builtin autoload -XUz
}
_who () {
	# undefined
	builtin autoload -XUz
}
_whois () {
	# undefined
	builtin autoload -XUz
}
_widgets () {
	# undefined
	builtin autoload -XUz
}
_wiggle () {
	# undefined
	builtin autoload -XUz
}
_wipefs () {
	# undefined
	builtin autoload -XUz
}
_wl-copy () {
	# undefined
	builtin autoload -XUz
}
_wl-paste () {
	# undefined
	builtin autoload -XUz
}
_wlogout () {
	# undefined
	builtin autoload -XUz
}
_wpa_cli () {
	# undefined
	builtin autoload -XUz
}
_wpctl () {
	# undefined
	builtin autoload -XUz
}
_x_arguments () {
	# undefined
	builtin autoload -XUz
}
_x_borderwidth () {
	# undefined
	builtin autoload -XUz
}
_x_color () {
	# undefined
	builtin autoload -XUz
}
_x_colormapid () {
	# undefined
	builtin autoload -XUz
}
_x_cursor () {
	# undefined
	builtin autoload -XUz
}
_x_display () {
	# undefined
	builtin autoload -XUz
}
_x_extension () {
	# undefined
	builtin autoload -XUz
}
_x_font () {
	# undefined
	builtin autoload -XUz
}
_x_geometry () {
	# undefined
	builtin autoload -XUz
}
_x_keysym () {
	# undefined
	builtin autoload -XUz
}
_x_locale () {
	# undefined
	builtin autoload -XUz
}
_x_modifier () {
	# undefined
	builtin autoload -XUz
}
_x_name () {
	# undefined
	builtin autoload -XUz
}
_x_resource () {
	# undefined
	builtin autoload -XUz
}
_x_selection_timeout () {
	# undefined
	builtin autoload -XUz
}
_x_title () {
	# undefined
	builtin autoload -XUz
}
_x_utils () {
	# undefined
	builtin autoload -XUz
}
_x_visual () {
	# undefined
	builtin autoload -XUz
}
_x_window () {
	# undefined
	builtin autoload -XUz
}
_xargs () {
	# undefined
	builtin autoload -XUz
}
_xauth () {
	# undefined
	builtin autoload -XUz
}
_xautolock () {
	# undefined
	builtin autoload -XUz
}
_xclip () {
	# undefined
	builtin autoload -XUz
}
_xcode-select () {
	# undefined
	builtin autoload -XUz
}
_xdvi () {
	# undefined
	builtin autoload -XUz
}
_xfig () {
	# undefined
	builtin autoload -XUz
}
_xft_fonts () {
	# undefined
	builtin autoload -XUz
}
_xinput () {
	# undefined
	builtin autoload -XUz
}
_xloadimage () {
	# undefined
	builtin autoload -XUz
}
_xmlsoft () {
	# undefined
	builtin autoload -XUz
}
_xmlstarlet () {
	# undefined
	builtin autoload -XUz
}
_xmms2 () {
	# undefined
	builtin autoload -XUz
}
_xmodmap () {
	# undefined
	builtin autoload -XUz
}
_xournal () {
	# undefined
	builtin autoload -XUz
}
_xpdf () {
	# undefined
	builtin autoload -XUz
}
_xrandr () {
	# undefined
	builtin autoload -XUz
}
_xscreensaver () {
	# undefined
	builtin autoload -XUz
}
_xset () {
	# undefined
	builtin autoload -XUz
}
_xt_arguments () {
	# undefined
	builtin autoload -XUz
}
_xt_session_id () {
	# undefined
	builtin autoload -XUz
}
_xterm () {
	# undefined
	builtin autoload -XUz
}
_xv () {
	# undefined
	builtin autoload -XUz
}
_xwit () {
	# undefined
	builtin autoload -XUz
}
_xxd () {
	# undefined
	builtin autoload -XUz
}
_xz () {
	# undefined
	builtin autoload -XUz
}
_yafc () {
	# undefined
	builtin autoload -XUz
}
_yast () {
	# undefined
	builtin autoload -XUz
}
_yazi () {
	# undefined
	builtin autoload -XUz
}
_yodl () {
	# undefined
	builtin autoload -XUz
}
_yp () {
	# undefined
	builtin autoload -XUz
}
_yum () {
	# undefined
	builtin autoload -XUz
}
_z () {
	# undefined
	builtin autoload -XUz
}
_zargs () {
	# undefined
	builtin autoload -XUz
}
_zattr () {
	# undefined
	builtin autoload -XUz
}
_zcalc () {
	# undefined
	builtin autoload -XUz
}
_zcalc_line () {
	# undefined
	builtin autoload -XUz
}
_zcat () {
	# undefined
	builtin autoload -XUz
}
_zcompile () {
	# undefined
	builtin autoload -XUz
}
_zdump () {
	# undefined
	builtin autoload -XUz
}
_zeal () {
	# undefined
	builtin autoload -XUz
}
_zed () {
	# undefined
	builtin autoload -XUz
}
_zfs () {
	# undefined
	builtin autoload -XUz
}
_zfs_dataset () {
	# undefined
	builtin autoload -XUz
}
_zfs_pool () {
	# undefined
	builtin autoload -XUz
}
_zftp () {
	# undefined
	builtin autoload -XUz
}
_zip () {
	# undefined
	builtin autoload -XUz
}
_zle () {
	# undefined
	builtin autoload -XUz
}
_zlogin () {
	# undefined
	builtin autoload -XUz
}
_zmodload () {
	# undefined
	builtin autoload -XUz
}
_zmv () {
	# undefined
	builtin autoload -XUz
}
_zoneadm () {
	# undefined
	builtin autoload -XUz
}
_zones () {
	# undefined
	builtin autoload -XUz
}
_zparseopts () {
	# undefined
	builtin autoload -XUz
}
_zpty () {
	# undefined
	builtin autoload -XUz
}
_zsh () {
	# undefined
	builtin autoload -XUz
}
_zsh-mime-handler () {
	# undefined
	builtin autoload -XUz
}
_zsh_autosuggest_accept () {
	local -i retval max_cursor_pos=$#BUFFER 
	if [[ "$KEYMAP" = "vicmd" ]]
	then
		max_cursor_pos=$((max_cursor_pos - 1)) 
	fi
	if (( $CURSOR != $max_cursor_pos || !$#POSTDISPLAY ))
	then
		_zsh_autosuggest_invoke_original_widget $@
		return
	fi
	BUFFER="$BUFFER$POSTDISPLAY" 
	POSTDISPLAY= 
	_zsh_autosuggest_invoke_original_widget $@
	retval=$? 
	if [[ "$KEYMAP" = "vicmd" ]]
	then
		CURSOR=$(($#BUFFER - 1)) 
	else
		CURSOR=$#BUFFER 
	fi
	return $retval
}
_zsh_autosuggest_async_request () {
	zmodload zsh/system 2> /dev/null
	typeset -g _ZSH_AUTOSUGGEST_ASYNC_FD _ZSH_AUTOSUGGEST_CHILD_PID
	if [[ -n "$_ZSH_AUTOSUGGEST_ASYNC_FD" ]] && {
			true <&$_ZSH_AUTOSUGGEST_ASYNC_FD
		} 2> /dev/null
	then
		builtin exec {_ZSH_AUTOSUGGEST_ASYNC_FD}<&-
		zle -F $_ZSH_AUTOSUGGEST_ASYNC_FD
		if [[ -n "$_ZSH_AUTOSUGGEST_CHILD_PID" ]]
		then
			if [[ -o MONITOR ]]
			then
				kill -TERM -$_ZSH_AUTOSUGGEST_CHILD_PID 2> /dev/null
			else
				kill -TERM $_ZSH_AUTOSUGGEST_CHILD_PID 2> /dev/null
			fi
		fi
	fi
	builtin exec {_ZSH_AUTOSUGGEST_ASYNC_FD}< <(
		# Tell parent process our pid
		echo $sysparams[pid]

		# Fetch and print the suggestion
		local suggestion
		_zsh_autosuggest_fetch_suggestion "$1"
		echo -nE "$suggestion"
	)
	autoload -Uz is-at-least
	is-at-least 5.8 || command true
	read _ZSH_AUTOSUGGEST_CHILD_PID <&$_ZSH_AUTOSUGGEST_ASYNC_FD
	zle -F "$_ZSH_AUTOSUGGEST_ASYNC_FD" _zsh_autosuggest_async_response
}
_zsh_autosuggest_async_response () {
	emulate -L zsh
	local suggestion
	if [[ -z "$2" || "$2" == "hup" ]]
	then
		IFS='' read -rd '' -u $1 suggestion
		zle autosuggest-suggest -- "$suggestion"
		builtin exec {1}<&-
	fi
	zle -F "$1"
	_ZSH_AUTOSUGGEST_ASYNC_FD= 
}
_zsh_autosuggest_bind_widget () {
	typeset -gA _ZSH_AUTOSUGGEST_BIND_COUNTS
	local widget=$1 
	local autosuggest_action=$2 
	local prefix=$ZSH_AUTOSUGGEST_ORIGINAL_WIDGET_PREFIX 
	local -i bind_count
	case $widgets[$widget] in
		(user:_zsh_autosuggest_(bound|orig)_*) bind_count=$((_ZSH_AUTOSUGGEST_BIND_COUNTS[$widget]))  ;;
		(user:*) _zsh_autosuggest_incr_bind_count $widget
			zle -N $prefix$bind_count-$widget ${widgets[$widget]#*:} ;;
		(builtin) _zsh_autosuggest_incr_bind_count $widget
			eval "_zsh_autosuggest_orig_${(q)widget}() { zle .${(q)widget} }"
			zle -N $prefix$bind_count-$widget _zsh_autosuggest_orig_$widget ;;
		(completion:*) _zsh_autosuggest_incr_bind_count $widget
			eval "zle -C $prefix$bind_count-${(q)widget} ${${(s.:.)widgets[$widget]}[2,3]}" ;;
	esac
	eval "_zsh_autosuggest_bound_${bind_count}_${(q)widget}() {
		_zsh_autosuggest_widget_$autosuggest_action $prefix$bind_count-${(q)widget} \$@
	}"
	zle -N -- $widget _zsh_autosuggest_bound_${bind_count}_$widget
}
_zsh_autosuggest_bind_widgets () {
	emulate -L zsh
	local widget
	local ignore_widgets
	ignore_widgets=(.\* _\* ${_ZSH_AUTOSUGGEST_BUILTIN_ACTIONS/#/autosuggest-} $ZSH_AUTOSUGGEST_ORIGINAL_WIDGET_PREFIX\* $ZSH_AUTOSUGGEST_IGNORE_WIDGETS) 
	for widget in ${${(f)"$(builtin zle -la)"}:#${(j:|:)~ignore_widgets}}
	do
		if [[ -n ${ZSH_AUTOSUGGEST_CLEAR_WIDGETS[(r)$widget]} ]]
		then
			_zsh_autosuggest_bind_widget $widget clear
		elif [[ -n ${ZSH_AUTOSUGGEST_ACCEPT_WIDGETS[(r)$widget]} ]]
		then
			_zsh_autosuggest_bind_widget $widget accept
		elif [[ -n ${ZSH_AUTOSUGGEST_EXECUTE_WIDGETS[(r)$widget]} ]]
		then
			_zsh_autosuggest_bind_widget $widget execute
		elif [[ -n ${ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS[(r)$widget]} ]]
		then
			_zsh_autosuggest_bind_widget $widget partial_accept
		else
			_zsh_autosuggest_bind_widget $widget modify
		fi
	done
}
_zsh_autosuggest_capture_completion_async () {
	_zsh_autosuggest_capture_setup
	zmodload zsh/parameter 2> /dev/null || return
	autoload +X _complete
	functions[_original_complete]=$functions[_complete] 
	_complete () {
		unset 'compstate[vared]'
		_original_complete "$@"
	}
	vared 1
}
_zsh_autosuggest_capture_completion_sync () {
	_zsh_autosuggest_capture_setup
	zle autosuggest-capture-completion
}
_zsh_autosuggest_capture_completion_widget () {
	local -a +h comppostfuncs
	comppostfuncs=(_zsh_autosuggest_capture_postcompletion) 
	CURSOR=$#BUFFER 
	zle -- ${(k)widgets[(r)completion:.complete-word:_main_complete]}
	if is-at-least 5.0.3
	then
		stty -onlcr -ocrnl -F /dev/tty
	fi
	echo -nE - $'\0'$BUFFER$'\0'
}
_zsh_autosuggest_capture_postcompletion () {
	compstate[insert]=1 
	unset 'compstate[list]'
}
_zsh_autosuggest_capture_setup () {
	if ! is-at-least 5.4
	then
		zshexit () {
			kill -KILL $$ 2>&- || command kill -KILL $$
			sleep 1
		}
	fi
	zstyle ':completion:*' matcher-list ''
	zstyle ':completion:*' path-completion false
	zstyle ':completion:*' max-errors 0 not-numeric
	bindkey '^I' autosuggest-capture-completion
}
_zsh_autosuggest_clear () {
	POSTDISPLAY= 
	_zsh_autosuggest_invoke_original_widget $@
}
_zsh_autosuggest_disable () {
	typeset -g _ZSH_AUTOSUGGEST_DISABLED
	_zsh_autosuggest_clear
}
_zsh_autosuggest_enable () {
	unset _ZSH_AUTOSUGGEST_DISABLED
	if (( $#BUFFER ))
	then
		_zsh_autosuggest_fetch
	fi
}
_zsh_autosuggest_escape_command () {
	setopt localoptions EXTENDED_GLOB
	echo -E "${1//(#m)[\"\'\\()\[\]|*?~]/\\$MATCH}"
}
_zsh_autosuggest_execute () {
	BUFFER="$BUFFER$POSTDISPLAY" 
	POSTDISPLAY= 
	_zsh_autosuggest_invoke_original_widget "accept-line"
}
_zsh_autosuggest_fetch () {
	if (( ${+ZSH_AUTOSUGGEST_USE_ASYNC} ))
	then
		_zsh_autosuggest_async_request "$BUFFER"
	else
		local suggestion
		_zsh_autosuggest_fetch_suggestion "$BUFFER"
		_zsh_autosuggest_suggest "$suggestion"
	fi
}
_zsh_autosuggest_fetch_suggestion () {
	typeset -g suggestion
	local -a strategies
	local strategy
	strategies=(${=ZSH_AUTOSUGGEST_STRATEGY}) 
	for strategy in $strategies
	do
		_zsh_autosuggest_strategy_$strategy "$1"
		[[ "$suggestion" != "$1"* ]] && unset suggestion
		[[ -n "$suggestion" ]] && break
	done
}
_zsh_autosuggest_highlight_apply () {
	typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	if (( $#POSTDISPLAY ))
	then
		typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT="$#BUFFER $(($#BUFFER + $#POSTDISPLAY)) $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE" 
		region_highlight+=("$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT") 
	else
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	fi
}
_zsh_autosuggest_highlight_reset () {
	typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	if [[ -n "$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT" ]]
	then
		region_highlight=("${(@)region_highlight:#$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT}") 
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	fi
}
_zsh_autosuggest_incr_bind_count () {
	typeset -gi bind_count=$((_ZSH_AUTOSUGGEST_BIND_COUNTS[$1]+1)) 
	_ZSH_AUTOSUGGEST_BIND_COUNTS[$1]=$bind_count 
}
_zsh_autosuggest_invoke_original_widget () {
	(( $# )) || return 0
	local original_widget_name="$1" 
	shift
	if (( ${+widgets[$original_widget_name]} ))
	then
		zle $original_widget_name -- $@
	fi
}
_zsh_autosuggest_modify () {
	local -i retval
	local -i KEYS_QUEUED_COUNT
	local orig_buffer="$BUFFER" 
	local orig_postdisplay="$POSTDISPLAY" 
	POSTDISPLAY= 
	_zsh_autosuggest_invoke_original_widget $@
	retval=$? 
	emulate -L zsh
	if (( $PENDING > 0 || $KEYS_QUEUED_COUNT > 0 ))
	then
		POSTDISPLAY="$orig_postdisplay" 
		return $retval
	fi
	if [[ "$BUFFER" = "$orig_buffer"* && "$orig_postdisplay" = "${BUFFER:$#orig_buffer}"* ]]
	then
		POSTDISPLAY="${orig_postdisplay:$(($#BUFFER - $#orig_buffer))}" 
		return $retval
	fi
	if (( ${+_ZSH_AUTOSUGGEST_DISABLED} ))
	then
		return $?
	fi
	if (( $#BUFFER > 0 ))
	then
		if [[ -z "$ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE" ]] || (( $#BUFFER <= $ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE ))
		then
			_zsh_autosuggest_fetch
		fi
	fi
	return $retval
}
_zsh_autosuggest_partial_accept () {
	local -i retval cursor_loc
	local original_buffer="$BUFFER" 
	BUFFER="$BUFFER$POSTDISPLAY" 
	_zsh_autosuggest_invoke_original_widget $@
	retval=$? 
	cursor_loc=$CURSOR 
	if [[ "$KEYMAP" = "vicmd" ]]
	then
		cursor_loc=$((cursor_loc + 1)) 
	fi
	if (( $cursor_loc > $#original_buffer ))
	then
		POSTDISPLAY="${BUFFER[$(($cursor_loc + 1)),$#BUFFER]}" 
		BUFFER="${BUFFER[1,$cursor_loc]}" 
	else
		BUFFER="$original_buffer" 
	fi
	return $retval
}
_zsh_autosuggest_start () {
	if (( ${+ZSH_AUTOSUGGEST_MANUAL_REBIND} ))
	then
		add-zsh-hook -d precmd _zsh_autosuggest_start
	fi
	_zsh_autosuggest_bind_widgets
}
_zsh_autosuggest_strategy_completion () {
	emulate -L zsh
	setopt EXTENDED_GLOB
	typeset -g suggestion
	local line REPLY
	whence compdef > /dev/null || return
	zmodload zsh/zpty 2> /dev/null || return
	[[ -n "$ZSH_AUTOSUGGEST_COMPLETION_IGNORE" ]] && [[ "$1" == $~ZSH_AUTOSUGGEST_COMPLETION_IGNORE ]] && return
	if zle
	then
		zpty $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME _zsh_autosuggest_capture_completion_sync
	else
		zpty $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME _zsh_autosuggest_capture_completion_async "\$1"
		zpty -w $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME $'\t'
	fi
	{
		zpty -r $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME line '*'$'\0''*'$'\0'
		suggestion="${${(@0)line}[2]}" 
	} always {
		zpty -d $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME
	}
}
_zsh_autosuggest_strategy_history () {
	emulate -L zsh
	setopt EXTENDED_GLOB
	local prefix="${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}" 
	local pattern="$prefix*" 
	if [[ -n $ZSH_AUTOSUGGEST_HISTORY_IGNORE ]]
	then
		pattern="($pattern)~($ZSH_AUTOSUGGEST_HISTORY_IGNORE)" 
	fi
	typeset -g suggestion="${history[(r)$pattern]}" 
}
_zsh_autosuggest_strategy_match_prev_cmd () {
	emulate -L zsh
	setopt EXTENDED_GLOB
	local prefix="${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}" 
	local pattern="$prefix*" 
	if [[ -n $ZSH_AUTOSUGGEST_HISTORY_IGNORE ]]
	then
		pattern="($pattern)~($ZSH_AUTOSUGGEST_HISTORY_IGNORE)" 
	fi
	local history_match_keys
	history_match_keys=(${(k)history[(R)$~pattern]}) 
	local histkey="${history_match_keys[1]}" 
	local prev_cmd="$(_zsh_autosuggest_escape_command "${history[$((HISTCMD-1))]}")" 
	for key in "${(@)history_match_keys[1,200]}"
	do
		[[ $key -gt 1 ]] || break
		if [[ "${history[$((key - 1))]}" == "$prev_cmd" ]]
		then
			histkey="$key" 
			break
		fi
	done
	typeset -g suggestion="$history[$histkey]" 
}
_zsh_autosuggest_suggest () {
	emulate -L zsh
	local suggestion="$1" 
	if [[ -n "$suggestion" ]] && (( $#BUFFER ))
	then
		POSTDISPLAY="${suggestion#$BUFFER}" 
	else
		POSTDISPLAY= 
	fi
}
_zsh_autosuggest_toggle () {
	if (( ${+_ZSH_AUTOSUGGEST_DISABLED} ))
	then
		_zsh_autosuggest_enable
	else
		_zsh_autosuggest_disable
	fi
}
_zsh_autosuggest_widget_accept () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_accept $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_clear () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_clear $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_disable () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_disable $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_enable () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_enable $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_execute () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_execute $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_fetch () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_fetch $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_modify () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_modify $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_partial_accept () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_partial_accept $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_suggest () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_suggest $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_toggle () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_toggle $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_highlight () {
	local ret=$? 
	typeset -r ret
	(( ${+region_highlight[@]} )) || {
		echo 'zsh-syntax-highlighting: error: $region_highlight is not defined' >&2
		echo 'zsh-syntax-highlighting: (Check whether zsh-syntax-highlighting was installed according to the instructions.)' >&2
		return $ret
	}
	(( ${+zsh_highlight__memo_feature} )) || {
		region_highlight+=(" 0 0 fg=red, memo=zsh-syntax-highlighting") 
		case ${region_highlight[-1]} in
			("0 0 fg=red") integer -gr zsh_highlight__memo_feature=0  ;;
			("0 0 fg=red memo=zsh-syntax-highlighting") integer -gr zsh_highlight__memo_feature=1  ;;
			(" 0 0 fg=red, memo=zsh-syntax-highlighting")  ;&
			(*) if is-at-least 5.9
				then
					integer -gr zsh_highlight__memo_feature=1 
				else
					integer -gr zsh_highlight__memo_feature=0 
				fi ;;
		esac
		region_highlight[-1]=() 
	}
	if (( zsh_highlight__memo_feature ))
	then
		region_highlight=("${(@)region_highlight:#*memo=zsh-syntax-highlighting*}") 
	else
		region_highlight=() 
	fi
	if [[ $WIDGET == zle-isearch-update ]] && {
			$zsh_highlight__pat_static_bug || ! (( $+ISEARCHMATCH_ACTIVE ))
		}
	then
		return $ret
	fi
	local -A zsyh_user_options
	if zmodload -e zsh/parameter
	then
		zsyh_user_options=("${(kv)options[@]}") 
	else
		local canonical_options onoff option raw_options
		raw_options=(${(f)"$(emulate -R zsh; set -o)"}) 
		canonical_options=(${${${(M)raw_options:#*off}%% *}#no} ${${(M)raw_options:#*on}%% *}) 
		for option in "${canonical_options[@]}"
		do
			[[ -o $option ]]
			case $? in
				(0) zsyh_user_options+=($option on)  ;;
				(1) zsyh_user_options+=($option off)  ;;
				(*) echo "zsh-syntax-highlighting: warning: '[[ -o $option ]]' returned $?" ;;
			esac
		done
	fi
	typeset -r zsyh_user_options
	emulate -L zsh
	setopt localoptions warncreateglobal nobashrematch
	local REPLY
	[[ -n ${ZSH_HIGHLIGHT_MAXLENGTH:-} ]] && [[ $#BUFFER -gt $ZSH_HIGHLIGHT_MAXLENGTH ]] && return $ret
	(( KEYS_QUEUED_COUNT > 0 )) && return $ret
	(( PENDING > 0 )) && return $ret
	{
		local cache_place
		local -a region_highlight_copy
		local highlighter
		for highlighter in $ZSH_HIGHLIGHT_HIGHLIGHTERS
		do
			cache_place="_zsh_highlight__highlighter_${highlighter}_cache" 
			typeset -ga ${cache_place}
			if ! type "_zsh_highlight_highlighter_${highlighter}_predicate" >&/dev/null
			then
				echo "zsh-syntax-highlighting: warning: disabling the ${(qq)highlighter} highlighter as it has not been loaded" >&2
				ZSH_HIGHLIGHT_HIGHLIGHTERS=(${ZSH_HIGHLIGHT_HIGHLIGHTERS:#${highlighter}}) 
			elif "_zsh_highlight_highlighter_${highlighter}_predicate"
			then
				region_highlight_copy=("${region_highlight[@]}") 
				region_highlight=() 
				{
					"_zsh_highlight_highlighter_${highlighter}_paint"
				} always {
					: ${(AP)cache_place::="${region_highlight[@]}"}
				}
				region_highlight=("${region_highlight_copy[@]}") 
			fi
			region_highlight+=("${(@P)cache_place}") 
		done
		() {
			(( REGION_ACTIVE )) || return
			integer min max
			if (( MARK > CURSOR ))
			then
				min=$CURSOR max=$MARK 
			else
				min=$MARK max=$CURSOR 
			fi
			if (( REGION_ACTIVE == 1 ))
			then
				[[ $KEYMAP = vicmd ]] && (( max++ ))
			elif (( REGION_ACTIVE == 2 ))
			then
				local needle=$'\n' 
				(( min = ${BUFFER[(Ib:min:)$needle]} ))
				(( max = ${BUFFER[(ib:max:)$needle]} - 1 ))
			fi
			_zsh_highlight_apply_zle_highlight region standout "$min" "$max"
		}
		(( $+YANK_ACTIVE )) && (( YANK_ACTIVE )) && _zsh_highlight_apply_zle_highlight paste standout "$YANK_START" "$YANK_END"
		(( $+ISEARCHMATCH_ACTIVE )) && (( ISEARCHMATCH_ACTIVE )) && _zsh_highlight_apply_zle_highlight isearch underline "$ISEARCHMATCH_START" "$ISEARCHMATCH_END"
		(( $+SUFFIX_ACTIVE )) && (( SUFFIX_ACTIVE )) && _zsh_highlight_apply_zle_highlight suffix bold "$SUFFIX_START" "$SUFFIX_END"
		return $ret
	} always {
		typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER="$BUFFER" 
		typeset -gi _ZSH_HIGHLIGHT_PRIOR_CURSOR=$CURSOR 
	}
}
_zsh_highlight__function_callable_p () {
	if _zsh_highlight__is_function_p "$1" && ! _zsh_highlight__function_is_autoload_stub_p "$1"
	then
		return 0
	else
		(
			autoload -U +X -- "$1" 2> /dev/null
		)
		return $?
	fi
}
_zsh_highlight__function_is_autoload_stub_p () {
	if zmodload -e zsh/parameter
	then
		[[ "$functions[$1]" == *"builtin autoload -X"* ]]
	else
		[[ "${${(@f)"$(which -- "$1")"}[2]}" == $'\t'$histchars[3]' undefined' ]]
	fi
}
_zsh_highlight__is_function_p () {
	if zmodload -e zsh/parameter
	then
		(( ${+functions[$1]} ))
	else
		[[ $(type -wa -- "$1") == *'function'* ]]
	fi
}
_zsh_highlight__zle-line-finish () {
	() {
		local -h -r WIDGET=zle-line-finish 
		_zsh_highlight
	}
}
_zsh_highlight__zle-line-pre-redraw () {
	true && _zsh_highlight "$@"
}
_zsh_highlight_add_highlight () {
	local -i start end
	local highlight
	start=$1 
	end=$2 
	shift 2
	for highlight
	do
		if (( $+ZSH_HIGHLIGHT_STYLES[$highlight] ))
		then
			region_highlight+=("$start $end $ZSH_HIGHLIGHT_STYLES[$highlight], memo=zsh-syntax-highlighting") 
			break
		fi
	done
}
_zsh_highlight_apply_zle_highlight () {
	local entry="$1" default="$2" 
	integer first="$3" second="$4" 
	local region="${zle_highlight[(r)${entry}:*]-}" 
	if [[ -z "$region" ]]
	then
		region=$default 
	else
		region="${region#${entry}:}" 
		if [[ -z "$region" ]] || [[ "$region" == none ]]
		then
			return
		fi
	fi
	integer start end
	if (( first < second ))
	then
		start=$first end=$second 
	else
		start=$second end=$first 
	fi
	region_highlight+=("$start $end $region, memo=zsh-syntax-highlighting") 
}
_zsh_highlight_bind_widgets () {
	
}
_zsh_highlight_brackets_match () {
	case $BUFFER[$1] in
		(\() [[ $BUFFER[$2] == \) ]] ;;
		(\[) [[ $BUFFER[$2] == \] ]] ;;
		(\{) [[ $BUFFER[$2] == \} ]] ;;
		(*) false ;;
	esac
}
_zsh_highlight_buffer_modified () {
	[[ "${_ZSH_HIGHLIGHT_PRIOR_BUFFER:-}" != "$BUFFER" ]]
}
_zsh_highlight_call_widget () {
	builtin zle "$@" && _zsh_highlight
}
_zsh_highlight_cursor_moved () {
	[[ -n $CURSOR ]] && [[ -n ${_ZSH_HIGHLIGHT_PRIOR_CURSOR-} ]] && (($_ZSH_HIGHLIGHT_PRIOR_CURSOR != $CURSOR))
}
_zsh_highlight_highlighter_brackets_paint () {
	local char style
	local -i bracket_color_size=${#ZSH_HIGHLIGHT_STYLES[(I)bracket-level-*]} buflen=${#BUFFER} level=0 matchingpos pos 
	local -A levelpos lastoflevel matching
	pos=0 
	for char in ${(s..)BUFFER}
	do
		(( ++pos ))
		case $char in
			(["([{"]) levelpos[$pos]=$((++level)) 
				lastoflevel[$level]=$pos  ;;
			([")]}"]) if (( level > 0 ))
				then
					matchingpos=$lastoflevel[$level] 
					levelpos[$pos]=$((level--)) 
					if _zsh_highlight_brackets_match $matchingpos $pos
					then
						matching[$matchingpos]=$pos 
						matching[$pos]=$matchingpos 
					fi
				else
					levelpos[$pos]=-1 
				fi ;;
		esac
	done
	for pos in ${(k)levelpos}
	do
		if (( $+matching[$pos] ))
		then
			if (( bracket_color_size ))
			then
				_zsh_highlight_add_highlight $((pos - 1)) $pos bracket-level-$(( (levelpos[$pos] - 1) % bracket_color_size + 1 ))
			fi
		else
			_zsh_highlight_add_highlight $((pos - 1)) $pos bracket-error
		fi
	done
	if [[ $WIDGET != zle-line-finish ]]
	then
		pos=$((CURSOR + 1)) 
		if (( $+levelpos[$pos] )) && (( $+matching[$pos] ))
		then
			local -i otherpos=$matching[$pos] 
			_zsh_highlight_add_highlight $((otherpos - 1)) $otherpos cursor-matchingbracket
		fi
	fi
}
_zsh_highlight_highlighter_brackets_predicate () {
	[[ $WIDGET == zle-line-finish ]] || _zsh_highlight_cursor_moved || _zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_cursor_paint () {
	[[ $WIDGET == zle-line-finish ]] && return
	_zsh_highlight_add_highlight $CURSOR $(( $CURSOR + 1 )) cursor
}
_zsh_highlight_highlighter_cursor_predicate () {
	[[ $WIDGET == zle-line-finish ]] || _zsh_highlight_cursor_moved
}
_zsh_highlight_highlighter_line_paint () {
	_zsh_highlight_add_highlight 0 $#BUFFER line
}
_zsh_highlight_highlighter_line_predicate () {
	_zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_main_paint () {
	setopt localoptions extendedglob
	if [[ $CONTEXT == (select|vared) ]]
	then
		return
	fi
	typeset -a ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR
	typeset -a ZSH_HIGHLIGHT_TOKENS_CONTROL_FLOW
	local -a options_to_set reply
	local REPLY
	local flags_with_argument
	local flags_sans_argument
	local flags_solo
	local -A precommand_options
	precommand_options=('-' '' 'builtin' '' 'command' :pvV 'exec' a:cl 'noglob' '' 'doas' aCu:Lns 'nice' n: 'pkexec' '' 'sudo' Cgprtu:AEHPSbilns:eKkVv 'stdbuf' ioe: 'eatmydata' '' 'catchsegv' '' 'nohup' '' 'setsid' :wc 'env' u:i 'ionice' cn:t:pPu 'strace' IbeaosXPpEuOS:ACdfhikqrtTvVxyDc 'proxychains' f:q 'torsocks' idq:upaP 'torify' idq:upaP 'ssh-agent' aEPt:csDd:k 'tabbed' gnprtTuU:cdfhs:v 'chronic' :ev 'ifne' :n 'grc' :se 'cpulimit' elp:ivz 'ktrace' fgpt:aBCcdiT) 
	if [[ $zsyh_user_options[ignorebraces] == on || ${zsyh_user_options[ignoreclosebraces]:-off} == on ]]
	then
		local right_brace_is_recognised_everywhere=false 
	else
		local right_brace_is_recognised_everywhere=true 
	fi
	if [[ $zsyh_user_options[pathdirs] == on ]]
	then
		options_to_set+=(PATH_DIRS) 
	fi
	ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR=('|' '||' ';' '&' '&&' $'\n' '|&' '&!' '&|') 
	ZSH_HIGHLIGHT_TOKENS_CONTROL_FLOW=($'\x7b' $'\x28' '()' 'while' 'until' 'if' 'then' 'elif' 'else' 'do' 'time' 'coproc' '!') 
	if (( $+X_ZSH_HIGHLIGHT_DIRS_BLACKLIST ))
	then
		print 'zsh-syntax-highlighting: X_ZSH_HIGHLIGHT_DIRS_BLACKLIST is deprecated. Please use ZSH_HIGHLIGHT_DIRS_BLACKLIST.' >&2
		ZSH_HIGHLIGHT_DIRS_BLACKLIST=($X_ZSH_HIGHLIGHT_DIRS_BLACKLIST) 
		unset X_ZSH_HIGHLIGHT_DIRS_BLACKLIST
	fi
	_zsh_highlight_main_highlighter_highlight_list -$#PREBUFFER '' 1 "$PREBUFFER$BUFFER"
	local start end_ style
	for start end_ style in $reply
	do
		(( start >= end_ )) && {
			print -r -- "zsh-syntax-highlighting: BUG: _zsh_highlight_highlighter_main_paint: start($start) >= end($end_)" >&2
			return
		}
		(( end_ <= 0 )) && continue
		(( start < 0 )) && start=0 
		_zsh_highlight_main_calculate_fallback $style
		_zsh_highlight_add_highlight $start $end_ $reply
	done
}
_zsh_highlight_highlighter_main_predicate () {
	[[ $WIDGET == zle-line-finish ]] || _zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_pattern_paint () {
	setopt localoptions extendedglob
	local pattern
	for pattern in ${(k)ZSH_HIGHLIGHT_PATTERNS}
	do
		_zsh_highlight_pattern_highlighter_loop "$BUFFER" "$pattern"
	done
}
_zsh_highlight_highlighter_pattern_predicate () {
	_zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_regexp_paint () {
	setopt localoptions extendedglob
	local pattern
	for pattern in ${(k)ZSH_HIGHLIGHT_REGEXP}
	do
		_zsh_highlight_regexp_highlighter_loop "$BUFFER" "$pattern"
	done
}
_zsh_highlight_highlighter_regexp_predicate () {
	_zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_root_paint () {
	if (( EUID == 0 ))
	then
		_zsh_highlight_add_highlight 0 $#BUFFER root
	fi
}
_zsh_highlight_highlighter_root_predicate () {
	_zsh_highlight_buffer_modified
}
_zsh_highlight_load_highlighters () {
	setopt localoptions noksharrays bareglobqual
	[[ -d "$1" ]] || {
		print -r -- "zsh-syntax-highlighting: highlighters directory ${(qq)1} not found." >&2
		return 1
	}
	local highlighter highlighter_dir
	for highlighter_dir in $1/*/(/)
	do
		highlighter="${highlighter_dir:t}" 
		[[ -f "$highlighter_dir${highlighter}-highlighter.zsh" ]] && . "$highlighter_dir${highlighter}-highlighter.zsh"
		if type "_zsh_highlight_highlighter_${highlighter}_paint" &> /dev/null && type "_zsh_highlight_highlighter_${highlighter}_predicate" &> /dev/null
		then
			
		elif type "_zsh_highlight_${highlighter}_highlighter" &> /dev/null && type "_zsh_highlight_${highlighter}_highlighter_predicate" &> /dev/null
		then
			if false
			then
				print -r -- "zsh-syntax-highlighting: warning: ${(qq)highlighter} highlighter uses deprecated entry point names; please ask its maintainer to update it: https://github.com/zsh-users/zsh-syntax-highlighting/issues/329" >&2
			fi
			eval "_zsh_highlight_highlighter_${(q)highlighter}_paint() { _zsh_highlight_${(q)highlighter}_highlighter \"\$@\" }"
			eval "_zsh_highlight_highlighter_${(q)highlighter}_predicate() { _zsh_highlight_${(q)highlighter}_highlighter_predicate \"\$@\" }"
		else
			print -r -- "zsh-syntax-highlighting: ${(qq)highlighter} highlighter should define both required functions '_zsh_highlight_highlighter_${highlighter}_paint' and '_zsh_highlight_highlighter_${highlighter}_predicate' in ${(qq):-"$highlighter_dir${highlighter}-highlighter.zsh"}." >&2
		fi
	done
}
_zsh_highlight_main__is_global_alias () {
	if zmodload -e zsh/parameter
	then
		(( ${+galiases[$arg]} ))
	elif [[ $arg == '='* ]]
	then
		return 1
	else
		alias -L -g -- "$1" > /dev/null
	fi
}
_zsh_highlight_main__is_redirection () {
	[[ $1 == (<0-9>|)(\<|\>)* ]] && [[ $1 != (\<|\>)$'\x28'* ]] && [[ $1 != *'<'*'-'*'>'* ]]
}
_zsh_highlight_main__is_runnable () {
	if _zsh_highlight_main__type "$1"
	then
		[[ $REPLY != none ]]
	else
		return 2
	fi
}
_zsh_highlight_main__precmd_hook () {
	setopt localoptions
	if eval '[[ -o warnnestedvar ]]' 2> /dev/null
	then
		unsetopt warnnestedvar
	fi
	_zsh_highlight_main__command_type_cache=() 
}
_zsh_highlight_main__resolve_alias () {
	if zmodload -e zsh/parameter
	then
		REPLY=${aliases[$arg]} 
	else
		REPLY="${"$(alias -- $arg)"#*=}" 
	fi
}
_zsh_highlight_main__stack_pop () {
	if [[ $braces_stack[1] == $1 ]]
	then
		braces_stack=${braces_stack:1} 
		if (( $+2 ))
		then
			style=$2 
		fi
		return 0
	else
		style=unknown-token 
		return 1
	fi
}
_zsh_highlight_main__type () {
	integer -r aliases_allowed=${2-1} 
	integer may_cache=1 
	if (( $+_zsh_highlight_main__command_type_cache ))
	then
		REPLY=$_zsh_highlight_main__command_type_cache[(e)$1] 
		if [[ -n "$REPLY" ]]
		then
			return
		fi
	fi
	if (( $#options_to_set ))
	then
		setopt localoptions $options_to_set
	fi
	unset REPLY
	if zmodload -e zsh/parameter
	then
		if (( $+aliases[(e)$1] ))
		then
			may_cache=0 
		fi
		if (( ${+galiases[(e)$1]} )) && (( aliases_allowed ))
		then
			REPLY='global alias' 
		elif (( $+aliases[(e)$1] )) && (( aliases_allowed ))
		then
			REPLY=alias 
		elif [[ $1 == *.* && -n ${1%.*} ]] && (( $+saliases[(e)${1##*.}] ))
		then
			REPLY='suffix alias' 
		elif (( $reswords[(Ie)$1] ))
		then
			REPLY=reserved 
		elif (( $+functions[(e)$1] ))
		then
			REPLY=function 
		elif (( $+builtins[(e)$1] ))
		then
			REPLY=builtin 
		elif (( $+commands[(e)$1] ))
		then
			REPLY=command 
		elif {
				[[ $1 != */* ]] || is-at-least 5.3
			} && ! (
				builtin type -w -- "$1"
			) > /dev/null 2>&1
		then
			REPLY=none 
		fi
	fi
	if ! (( $+REPLY ))
	then
		REPLY="${$(:; (( aliases_allowed )) || unalias -- "$1" 2>/dev/null; LC_ALL=C builtin type -w -- "$1" 2>/dev/null)##*: }" 
		if [[ $REPLY == 'alias' ]]
		then
			may_cache=0 
		fi
	fi
	if (( may_cache )) && (( $+_zsh_highlight_main__command_type_cache ))
	then
		_zsh_highlight_main__command_type_cache[(e)$1]=$REPLY 
	fi
	[[ -n $REPLY ]]
	return $?
}
_zsh_highlight_main_add_many_region_highlights () {
	for 1 2 3
	do
		_zsh_highlight_main_add_region_highlight $1 $2 $3
	done
}
_zsh_highlight_main_add_region_highlight () {
	integer start=$1 end=$2 
	shift 2
	if (( $#in_alias ))
	then
		[[ $1 == unknown-token ]] && alias_style=unknown-token 
		return
	fi
	if (( in_param ))
	then
		if [[ $1 == unknown-token ]]
		then
			param_style=unknown-token 
		fi
		if [[ -n $param_style ]]
		then
			return
		fi
		param_style=$1 
		return
	fi
	(( start += buf_offset ))
	(( end += buf_offset ))
	list_highlights+=($start $end $1) 
}
_zsh_highlight_main_calculate_fallback () {
	local -A fallback_of
	fallback_of=(alias arg0 suffix-alias arg0 global-alias dollar-double-quoted-argument builtin arg0 function arg0 command arg0 precommand arg0 hashed-command arg0 autodirectory arg0 arg0_\* arg0 path_prefix path path_pathseparator path path_prefix_pathseparator path_prefix single-quoted-argument{-unclosed,} double-quoted-argument{-unclosed,} dollar-quoted-argument{-unclosed,} back-quoted-argument{-unclosed,} command-substitution{-quoted,,-unquoted,} command-substitution-delimiter{-quoted,,-unquoted,} command-substitution{-delimiter,} process-substitution{-delimiter,} back-quoted-argument{-delimiter,}) 
	local needle=$1 value 
	reply=($1) 
	while [[ -n ${value::=$fallback_of[(k)$needle]} ]]
	do
		unset "fallback_of[$needle]"
		reply+=($value) 
		needle=$value 
	done
}
_zsh_highlight_main_highlighter__try_expand_parameter () {
	local arg="$1" 
	unset reply
	{
		{
			local -a match mbegin mend
			local MATCH
			integer MBEGIN MEND
			local parameter_name
			local -a words
			if [[ $arg[1] != '$' ]]
			then
				return 1
			fi
			if [[ ${arg[2]} == '{' ]] && [[ ${arg[-1]} == '}' ]]
			then
				parameter_name=${${arg:2}%?} 
			else
				parameter_name=${arg:1} 
			fi
			if [[ $res == none ]] && [[ ${parameter_name} =~ ^${~parameter_name_pattern}$ ]] && [[ ${(tP)MATCH} != *special* ]]
			then
				case ${(tP)MATCH} in
					(*array*|*assoc*) words=(${(P)MATCH})  ;;
					("") words=()  ;;
					(*) if [[ $zsyh_user_options[shwordsplit] == on ]]
						then
							words=(${(P)=MATCH}) 
						else
							words=(${(P)MATCH}) 
						fi ;;
				esac
				reply=("${words[@]}") 
			else
				return 1
			fi
		}
	}
}
_zsh_highlight_main_highlighter_check_assign () {
	setopt localoptions extended_glob
	[[ $arg == [[:alpha:]_][[:alnum:]_]#(|\[*\])(|[+])=* ]] || [[ $arg == [0-9]##(|[+])=* ]]
}
_zsh_highlight_main_highlighter_check_path () {
	_zsh_highlight_main_highlighter_expand_path "$1"
	local expanded_path="$REPLY" tmp_path 
	integer in_command_position=$2 
	if [[ $zsyh_user_options[autocd] == on ]]
	then
		integer autocd=1 
	else
		integer autocd=0 
	fi
	if (( in_command_position ))
	then
		REPLY=arg0 
	else
		REPLY=path 
	fi
	if [[ ${1[1]} == '=' && $1 == ??* && ${1[2]} != $'\x28' && $zsyh_user_options[equals] == 'on' && $expanded_path[1] != '/' ]]
	then
		REPLY=unknown-token 
		return 0
	fi
	[[ -z $expanded_path ]] && return 1
	if [[ $expanded_path[1] == / ]]
	then
		tmp_path=$expanded_path 
	else
		tmp_path=$PWD/$expanded_path 
	fi
	tmp_path=$tmp_path:a 
	while [[ $tmp_path != / ]]
	do
		[[ -n ${(M)ZSH_HIGHLIGHT_DIRS_BLACKLIST:#$tmp_path} ]] && return 1
		tmp_path=$tmp_path:h 
	done
	if (( in_command_position ))
	then
		if [[ -x $expanded_path ]]
		then
			if (( autocd ))
			then
				if [[ -d $expanded_path ]]
				then
					REPLY=autodirectory 
				fi
				return 0
			elif [[ ! -d $expanded_path ]]
			then
				return 0
			fi
		fi
	else
		if [[ -L $expanded_path || -e $expanded_path ]]
		then
			return 0
		fi
	fi
	if [[ $expanded_path != /* ]] && (( autocd || ! in_command_position ))
	then
		local cdpath_dir
		for cdpath_dir in $cdpath
		do
			if [[ -d "$cdpath_dir/$expanded_path" && -x "$cdpath_dir/$expanded_path" ]]
			then
				if (( in_command_position && autocd ))
				then
					REPLY=autodirectory 
				fi
				return 0
			fi
		done
	fi
	[[ ! -d ${expanded_path:h} ]] && return 1
	if (( has_end && (len == end_pos) )) && (( ! $#in_alias )) && [[ $WIDGET != zle-line-finish ]]
	then
		local -a tmp
		if (( in_command_position ))
		then
			tmp=(${expanded_path}*(N-*,N-/)) 
		else
			tmp=(${expanded_path}*(N)) 
		fi
		(( ${+tmp[1]} )) && REPLY=path_prefix  && return 0
	fi
	return 1
}
_zsh_highlight_main_highlighter_expand_path () {
	(( $# == 1 )) || print -r -- "zsh-syntax-highlighting: BUG: _zsh_highlight_main_highlighter_expand_path: called without argument" >&2
	setopt localoptions nonomatch
	unset REPLY
	: ${REPLY:=${(Q)${~1}}}
}
_zsh_highlight_main_highlighter_highlight_argument () {
	local base_style=default i=$1 option_eligible=${2:-1} path_eligible=1 ret start style 
	local -a highlights
	local -a match mbegin mend
	local MATCH
	integer MBEGIN MEND
	case "$arg[i]" in
		('%') if [[ $arg[i+1] == '?' ]]
			then
				(( i += 2 ))
			fi ;;
		('-') if (( option_eligible ))
			then
				if [[ $arg[i+1] == - ]]
				then
					base_style=double-hyphen-option 
				else
					base_style=single-hyphen-option 
				fi
				path_eligible=0 
			fi ;;
		('=') if [[ $arg[i+1] == $'\x28' ]]
			then
				(( i += 2 ))
				_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,-1]
				ret=$? 
				(( i += REPLY ))
				highlights+=($(( start_pos + $1 - 1 )) $(( start_pos + i )) process-substitution $(( start_pos + $1 - 1 )) $(( start_pos + $1 + 1 )) process-substitution-delimiter $reply) 
				if (( ret == 0 ))
				then
					highlights+=($(( start_pos + i - 1 )) $(( start_pos + i )) process-substitution-delimiter) 
				fi
			fi ;;
	esac
	(( --i ))
	while (( ++i <= $#arg ))
	do
		i=${arg[(ib.i.)[\\\'\"\`\$\<\>\*\?]]} 
		case "$arg[$i]" in
			("") break ;;
			("\\") (( i += 1 ))
				continue ;;
			("'") _zsh_highlight_main_highlighter_highlight_single_quote $i
				(( i = REPLY ))
				highlights+=($reply)  ;;
			('"') _zsh_highlight_main_highlighter_highlight_double_quote $i
				(( i = REPLY ))
				highlights+=($reply)  ;;
			('`') _zsh_highlight_main_highlighter_highlight_backtick $i
				(( i = REPLY ))
				highlights+=($reply)  ;;
			('$') if [[ $arg[i+1] != "'" ]]
				then
					path_eligible=0 
				fi
				if [[ $arg[i+1] == "'" ]]
				then
					_zsh_highlight_main_highlighter_highlight_dollar_quote $i
					(( i = REPLY ))
					highlights+=($reply) 
					continue
				elif [[ $arg[i+1] == $'\x28' ]]
				then
					if [[ $arg[i+2] == $'\x28' ]] && _zsh_highlight_main_highlighter_highlight_arithmetic $i
					then
						(( i = REPLY ))
						highlights+=($reply) 
						continue
					fi
					start=$i 
					(( i += 2 ))
					_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,-1]
					ret=$? 
					(( i += REPLY ))
					highlights+=($(( start_pos + start - 1)) $(( start_pos + i )) command-substitution-unquoted $(( start_pos + start - 1)) $(( start_pos + start + 1)) command-substitution-delimiter-unquoted $reply) 
					if (( ret == 0 ))
					then
						highlights+=($(( start_pos + i - 1)) $(( start_pos + i )) command-substitution-delimiter-unquoted) 
					fi
					continue
				fi
				while [[ $arg[i+1] == [=~#+'^'] ]]
				do
					(( i += 1 ))
				done
				if [[ $arg[i+1] == [*@#?$!-] ]]
				then
					(( i += 1 ))
				fi ;;
			([\<\>]) if [[ $arg[i+1] == $'\x28' ]]
				then
					start=$i 
					(( i += 2 ))
					_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,-1]
					ret=$? 
					(( i += REPLY ))
					highlights+=($(( start_pos + start - 1)) $(( start_pos + i )) process-substitution $(( start_pos + start - 1)) $(( start_pos + start + 1 )) process-substitution-delimiter $reply) 
					if (( ret == 0 ))
					then
						highlights+=($(( start_pos + i - 1)) $(( start_pos + i )) process-substitution-delimiter) 
					fi
					continue
				fi ;|
			(*) if $highlight_glob && [[ $zsyh_user_options[multios] == on || $in_redirection -eq 0 ]] && [[ ${arg[$i]} =~ ^[*?] || ${arg:$i-1} =~ ^\<[0-9]*-[0-9]*\> ]]
				then
					highlights+=($(( start_pos + i - 1 )) $(( start_pos + i + $#MATCH - 1)) globbing) 
					(( i += $#MATCH - 1 ))
					path_eligible=0 
				else
					continue
				fi ;;
		esac
	done
	if (( path_eligible ))
	then
		if (( in_redirection )) && [[ $last_arg == *['<>']['&'] && $arg[$1,-1] == (<0->|p|-) ]]
		then
			if [[ $arg[$1,-1] == (p|-) ]]
			then
				base_style=redirection 
			else
				base_style=numeric-fd 
			fi
		elif _zsh_highlight_main_highlighter_check_path $arg[$1,-1] 0
		then
			base_style=$REPLY 
			_zsh_highlight_main_highlighter_highlight_path_separators $base_style
			highlights+=($reply) 
		fi
	fi
	highlights=($(( start_pos + $1 - 1 )) $end_pos $base_style $highlights) 
	_zsh_highlight_main_add_many_region_highlights $highlights
}
_zsh_highlight_main_highlighter_highlight_arithmetic () {
	local -a saved_reply
	local style
	integer i j k paren_depth ret
	reply=() 
	for ((i = $1 + 3 ; i <= end_pos - start_pos ; i += 1 )) do
		(( j = i + start_pos - 1 ))
		(( k = j + 1 ))
		case "$arg[$i]" in
			([\'\"\\@{}]) style=unknown-token  ;;
			('(') (( paren_depth++ ))
				continue ;;
			(')') if (( paren_depth ))
				then
					(( paren_depth-- ))
					continue
				fi
				[[ $arg[i+1] == ')' ]] && {
					(( i++ ))
					break
				}
				(( has_end && (len == k) )) && break
				return 1 ;;
			('`') saved_reply=($reply) 
				_zsh_highlight_main_highlighter_highlight_backtick $i
				(( i = REPLY ))
				reply=($saved_reply $reply) 
				continue ;;
			('$') if [[ $arg[i+1] == $'\x28' ]]
				then
					saved_reply=($reply) 
					if [[ $arg[i+2] == $'\x28' ]] && _zsh_highlight_main_highlighter_highlight_arithmetic $i
					then
						(( i = REPLY ))
						reply=($saved_reply $reply) 
						continue
					fi
					(( i += 2 ))
					_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,end_pos]
					ret=$? 
					(( i += REPLY ))
					reply=($saved_reply $j $(( start_pos + i )) command-substitution-quoted $j $(( j + 2 )) command-substitution-delimiter-quoted $reply) 
					if (( ret == 0 ))
					then
						reply+=($(( start_pos + i - 1 )) $(( start_pos + i )) command-substitution-delimiter) 
					fi
					continue
				else
					continue
				fi ;;
			($histchars[1]) if [[ $arg[i+1] != ('='|$'\x28'|$'\x7b'|[[:blank:]]) ]]
				then
					style=history-expansion 
				else
					continue
				fi ;;
			(*) continue ;;
		esac
		reply+=($j $k $style) 
	done
	if [[ $arg[i] != ')' ]]
	then
		(( i-- ))
	fi
	style=arithmetic-expansion 
	reply=($(( start_pos + $1 - 1)) $(( start_pos + i )) arithmetic-expansion $reply) 
	REPLY=$i 
}
_zsh_highlight_main_highlighter_highlight_backtick () {
	local buf highlight style=back-quoted-argument-unclosed style_end 
	local -i arg1=$1 end_ i=$1 last offset=0 start subshell_has_end=0 
	local -a highlight_zone highlights offsets
	reply=() 
	last=$(( arg1 + 1 )) 
	while i=$arg[(ib:i+1:)[\\\\\`]] 
	do
		if (( i > $#arg ))
		then
			buf=$buf$arg[last,i] 
			offsets[i-arg1-offset]='' 
			(( i-- ))
			subshell_has_end=$(( has_end && (start_pos + i == len) )) 
			break
		fi
		if [[ $arg[i] == '\' ]]
		then
			(( i++ ))
			if [[ $arg[i] == ('$'|'`'|'\') ]]
			then
				buf=$buf$arg[last,i-2] 
				(( offset++ ))
				offsets[i-arg1-offset]=$offset 
			else
				buf=$buf$arg[last,i-1] 
			fi
		else
			style=back-quoted-argument 
			style_end=back-quoted-argument-delimiter 
			buf=$buf$arg[last,i-1] 
			offsets[i-arg1-offset]='' 
			break
		fi
		last=$i 
	done
	_zsh_highlight_main_highlighter_highlight_list 0 '' $subshell_has_end $buf
	for start end_ highlight in $reply
	do
		start=$(( start_pos + arg1 + start + offsets[(Rb:start:)?*] )) 
		end_=$(( start_pos + arg1 + end_ + offsets[(Rb:end_:)?*] )) 
		highlights+=($start $end_ $highlight) 
		if [[ $highlight == back-quoted-argument-unclosed && $style == back-quoted-argument ]]
		then
			style_end=unknown-token 
		fi
	done
	reply=($(( start_pos + arg1 - 1 )) $(( start_pos + i )) $style $(( start_pos + arg1 - 1 )) $(( start_pos + arg1 )) back-quoted-argument-delimiter $highlights) 
	if (( $#style_end ))
	then
		reply+=($(( start_pos + i - 1)) $(( start_pos + i )) $style_end) 
	fi
	REPLY=$i 
}
_zsh_highlight_main_highlighter_highlight_dollar_quote () {
	local -a match mbegin mend
	local MATCH
	integer MBEGIN MEND
	local i j k style
	local AA
	integer c
	reply=() 
	for ((i = $1 + 2 ; i <= $#arg ; i += 1 )) do
		(( j = i + start_pos - 1 ))
		(( k = j + 1 ))
		case "$arg[$i]" in
			("'") break ;;
			("\\") style=back-dollar-quoted-argument 
				for ((c = i + 1 ; c <= $#arg ; c += 1 )) do
					[[ "$arg[$c]" != ([0-9xXuUa-fA-F]) ]] && break
				done
				AA=$arg[$i+1,$c-1] 
				if [[ "$AA" =~ "^(x|X)[0-9a-fA-F]{1,2}" || "$AA" =~ "^[0-7]{1,3}" || "$AA" =~ "^u[0-9a-fA-F]{1,4}" || "$AA" =~ "^U[0-9a-fA-F]{1,8}" ]]
				then
					(( k += $#MATCH ))
					(( i += $#MATCH ))
				else
					if (( $#arg > $i+1 )) && [[ $arg[$i+1] == [xXuU] ]]
					then
						style=unknown-token 
					fi
					(( k += 1 ))
					(( i += 1 ))
				fi ;;
			(*) continue ;;
		esac
		reply+=($j $k $style) 
	done
	if [[ $arg[i] == "'" ]]
	then
		style=dollar-quoted-argument 
	else
		(( i-- ))
		style=dollar-quoted-argument-unclosed 
	fi
	reply=($(( start_pos + $1 - 1 )) $(( start_pos + i )) $style $reply) 
	REPLY=$i 
}
_zsh_highlight_main_highlighter_highlight_double_quote () {
	local -a breaks match mbegin mend saved_reply
	local MATCH
	integer last_break=$(( start_pos + $1 - 1 )) MBEGIN MEND 
	local i j k ret style
	reply=() 
	for ((i = $1 + 1 ; i <= $#arg ; i += 1 )) do
		(( j = i + start_pos - 1 ))
		(( k = j + 1 ))
		case "$arg[$i]" in
			('"') break ;;
			('`') saved_reply=($reply) 
				_zsh_highlight_main_highlighter_highlight_backtick $i
				(( i = REPLY ))
				reply=($saved_reply $reply) 
				continue ;;
			('$') style=dollar-double-quoted-argument 
				if [[ ${arg:$i} =~ ^([A-Za-z_][A-Za-z0-9_]*|[0-9]+) ]]
				then
					(( k += $#MATCH ))
					(( i += $#MATCH ))
				elif [[ ${arg:$i} =~ ^[{]([A-Za-z_][A-Za-z0-9_]*|[0-9]+)[}] ]]
				then
					(( k += $#MATCH ))
					(( i += $#MATCH ))
				elif [[ $arg[i+1] == '$' ]]
				then
					(( k += 1 ))
					(( i += 1 ))
				elif [[ $arg[i+1] == [-#*@?] ]]
				then
					(( k += 1 ))
					(( i += 1 ))
				elif [[ $arg[i+1] == $'\x28' ]]
				then
					saved_reply=($reply) 
					if [[ $arg[i+2] == $'\x28' ]] && _zsh_highlight_main_highlighter_highlight_arithmetic $i
					then
						(( i = REPLY ))
						reply=($saved_reply $reply) 
						continue
					fi
					breaks+=($last_break $(( start_pos + i - 1 ))) 
					(( i += 2 ))
					_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,-1]
					ret=$? 
					(( i += REPLY ))
					last_break=$(( start_pos + i )) 
					reply=($saved_reply $j $(( start_pos + i )) command-substitution-quoted $j $(( j + 2 )) command-substitution-delimiter-quoted $reply) 
					if (( ret == 0 ))
					then
						reply+=($(( start_pos + i - 1 )) $(( start_pos + i )) command-substitution-delimiter-quoted) 
					fi
					continue
				else
					continue
				fi ;;
			("\\") style=back-double-quoted-argument 
				if [[ \\\`\"\$${histchars[1]} == *$arg[$i+1]* ]]
				then
					(( k += 1 ))
					(( i += 1 ))
				else
					continue
				fi ;;
			($histchars[1]) if [[ $arg[i+1] != ('='|$'\x28'|$'\x7b'|[[:blank:]]) ]]
				then
					style=history-expansion 
				else
					continue
				fi ;;
			(*) continue ;;
		esac
		reply+=($j $k $style) 
	done
	if [[ $arg[i] == '"' ]]
	then
		style=double-quoted-argument 
	else
		(( i-- ))
		style=double-quoted-argument-unclosed 
	fi
	(( last_break != start_pos + i )) && breaks+=($last_break $(( start_pos + i ))) 
	saved_reply=($reply) 
	reply=() 
	for 1 2 in $breaks
	do
		(( $1 != $2 )) && reply+=($1 $2 $style) 
	done
	reply+=($saved_reply) 
	REPLY=$i 
}
_zsh_highlight_main_highlighter_highlight_list () {
	integer start_pos end_pos=0 buf_offset=$1 has_end=$3 
	local alias_style param_style last_arg arg buf=$4 highlight_glob=true saw_assignment=false style 
	local in_array_assignment=false 
	integer in_param=0 len=$#buf 
	local -a in_alias match mbegin mend list_highlights
	local -A seen_alias
	readonly parameter_name_pattern='([A-Za-z_][A-Za-z0-9_]*|[0-9]+)' 
	list_highlights=() 
	local braces_stack=$2 
	local this_word next_word=':start::start_of_pipeline:' 
	integer in_redirection
	local proc_buf="$buf" 
	local -a args
	if [[ $zsyh_user_options[interactivecomments] == on ]]
	then
		args=(${(zZ+c+)buf}) 
	else
		args=(${(z)buf}) 
	fi
	if [[ $braces_stack == 'S' ]] && (( $+args[3] && ! $+args[4] )) && [[ $args[3] == $'\x29' ]] && [[ $args[1] == *'<'* ]] && _zsh_highlight_main__is_redirection $args[1]
	then
		highlight_glob=false 
	fi
	while (( $#args ))
	do
		last_arg=$arg 
		arg=$args[1] 
		shift args
		if (( $#in_alias ))
		then
			(( in_alias[1]-- ))
			in_alias=($in_alias[$in_alias[(i)<1->],-1]) 
			if (( $#in_alias == 0 ))
			then
				seen_alias=() 
				_zsh_highlight_main_add_region_highlight $start_pos $end_pos $alias_style
			else
				() {
					local alias_name
					for alias_name in ${(k)seen_alias[(R)<$#in_alias->]}
					do
						seen_alias=("${(@kv)seen_alias[(I)^$alias_name]}") 
					done
				}
			fi
		fi
		if (( in_param ))
		then
			(( in_param-- ))
			if (( in_param == 0 ))
			then
				_zsh_highlight_main_add_region_highlight $start_pos $end_pos $param_style
				param_style="" 
			fi
		fi
		if (( in_redirection == 0 ))
		then
			this_word=$next_word 
			next_word=':regular:' 
		elif (( !in_param ))
		then
			(( --in_redirection ))
		fi
		style=unknown-token 
		if [[ $this_word == *':start:'* ]]
		then
			in_array_assignment=false 
			if [[ $arg == 'noglob' ]]
			then
				highlight_glob=false 
			fi
		fi
		if (( $#in_alias == 0 && in_param == 0 ))
		then
			[[ "$proc_buf" = (#b)(#s)(''([ $'\t']|[\\]$'\n')#)(?|)* ]]
			integer offset="${#match[1]}" 
			(( start_pos = end_pos + offset ))
			(( end_pos = start_pos + $#arg ))
			[[ $arg == ';' && ${match[3]} == $'\n' ]] && arg=$'\n' 
			proc_buf="${proc_buf[offset + $#arg + 1,len]}" 
		fi
		if [[ $zsyh_user_options[interactivecomments] == on && $arg[1] == $histchars[3] ]]
		then
			if [[ $this_word == *(':regular:'|':start:')* ]]
			then
				style=comment 
			else
				style=unknown-token 
			fi
			_zsh_highlight_main_add_region_highlight $start_pos $end_pos $style
			in_redirection=1 
			continue
		fi
		if [[ $this_word == *':start:'* ]] && ! (( in_redirection ))
		then
			_zsh_highlight_main__type "$arg" "$(( ! ${+seen_alias[$arg]} ))"
			local res="$REPLY" 
			if [[ $res == "alias" ]]
			then
				if [[ $arg == ?*=* ]]
				then
					_zsh_highlight_main_add_region_highlight $start_pos $end_pos unknown-token
					continue
				fi
				seen_alias[$arg]=$#in_alias 
				_zsh_highlight_main__resolve_alias $arg
				local -a alias_args
				if [[ $zsyh_user_options[interactivecomments] == on ]]
				then
					alias_args=(${(zZ+c+)REPLY}) 
				else
					alias_args=(${(z)REPLY}) 
				fi
				args=($alias_args $args) 
				if (( $#in_alias == 0 ))
				then
					alias_style=alias 
				else
					(( in_alias[1]-- ))
				fi
				in_alias=($(($#alias_args + 1)) $in_alias) 
				(( in_redirection++ ))
				continue
			else
				_zsh_highlight_main_highlighter_expand_path $arg
				_zsh_highlight_main__type "$REPLY" 0
				res="$REPLY" 
			fi
		fi
		if _zsh_highlight_main__is_redirection $arg
		then
			if (( in_redirection == 1 ))
			then
				_zsh_highlight_main_add_region_highlight $start_pos $end_pos unknown-token
			else
				in_redirection=2 
				_zsh_highlight_main_add_region_highlight $start_pos $end_pos redirection
			fi
			continue
		elif [[ $arg == '{'${~parameter_name_pattern}'}' ]] && _zsh_highlight_main__is_redirection $args[1]
		then
			in_redirection=3 
			_zsh_highlight_main_add_region_highlight $start_pos $end_pos named-fd
			continue
		fi
		if (( ! in_param )) && _zsh_highlight_main_highlighter__try_expand_parameter "$arg"
		then
			() {
				local -a words
				words=("${reply[@]}") 
				if (( $#words == 0 )) && (( ! in_redirection ))
				then
					(( ++in_redirection ))
					_zsh_highlight_main_add_region_highlight $start_pos $end_pos comment
					continue
				else
					(( in_param = 1 + $#words ))
					args=($words $args) 
					arg=$args[1] 
					_zsh_highlight_main__type "$arg" 0
					res=$REPLY 
				fi
			}
		fi
		if (( ! in_redirection ))
		then
			if [[ $this_word == *':sudo_opt:'* ]]
			then
				if [[ -n $flags_with_argument ]] && {
						if [[ -n $flags_sans_argument ]]
						then
							[[ $arg == '-'[$flags_sans_argument]#[$flags_with_argument] ]]
						else
							[[ $arg == '-'[$flags_with_argument] ]]
						fi
					}
				then
					this_word=${this_word//:start:/} 
					next_word=':sudo_arg:' 
				elif [[ -n $flags_with_argument ]] && {
						if [[ -n $flags_sans_argument ]]
						then
							[[ $arg == '-'[$flags_sans_argument]#[$flags_with_argument]* ]]
						else
							[[ $arg == '-'[$flags_with_argument]* ]]
						fi
					}
				then
					this_word=${this_word//:start:/} 
					next_word+=':start:' 
					next_word+=':sudo_opt:' 
				elif [[ -n $flags_sans_argument ]] && [[ $arg == '-'[$flags_sans_argument]# ]]
				then
					this_word=':sudo_opt:' 
					next_word+=':start:' 
					next_word+=':sudo_opt:' 
				elif [[ -n $flags_solo ]] && {
						if [[ -n $flags_sans_argument ]]
						then
							[[ $arg == '-'[$flags_sans_argument]#[$flags_solo]* ]]
						else
							[[ $arg == '-'[$flags_solo]* ]]
						fi
					}
				then
					this_word=':sudo_opt:' 
					next_word=':regular:' 
				elif [[ $arg == '-'* ]]
				then
					this_word=':sudo_opt:' 
					next_word+=':start:' 
					next_word+=':sudo_opt:' 
				else
					this_word=${this_word//:sudo_opt:/} 
				fi
			elif [[ $this_word == *':sudo_arg:'* ]]
			then
				next_word+=':sudo_opt:' 
				next_word+=':start:' 
			fi
		fi
		if [[ -n ${(M)ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR:#"$arg"} ]] && [[ $braces_stack != *T* || $arg != ('||'|'&&') ]]
		then
			if _zsh_highlight_main__stack_pop T || _zsh_highlight_main__stack_pop Q
			then
				style=unknown-token 
			elif $in_array_assignment
			then
				case $arg in
					($'\n') style=commandseparator  ;;
					(';') style=unknown-token  ;;
					(*) style=unknown-token  ;;
				esac
			elif [[ $this_word == *':regular:'* ]]
			then
				style=commandseparator 
			elif [[ $this_word == *':start:'* ]] && [[ $arg == $'\n' ]]
			then
				style=commandseparator 
			elif [[ $this_word == *':start:'* ]] && [[ $arg == ';' ]] && (( $#in_alias ))
			then
				style=commandseparator 
			else
				style=unknown-token 
			fi
			if [[ $arg == $'\n' ]] && $in_array_assignment
			then
				next_word=':regular:' 
			elif [[ $arg == ';' ]] && $in_array_assignment
			then
				next_word=':regular:' 
			else
				next_word=':start:' 
				highlight_glob=true 
				saw_assignment=false 
				() {
					local alias_name
					for alias_name in ${(k)seen_alias[(R)<$#in_alias->]}
					do
						seen_alias=("${(@kv)seen_alias[(I)^$alias_name]}") 
					done
				}
				if [[ $arg != '|' && $arg != '|&' ]]
				then
					next_word+=':start_of_pipeline:' 
				fi
			fi
		elif ! (( in_redirection)) && [[ $this_word == *':always:'* && $arg == 'always' ]]
		then
			style=reserved-word 
			highlight_glob=true 
			saw_assignment=false 
			next_word=':start::start_of_pipeline:' 
		elif ! (( in_redirection)) && [[ $this_word == *':start:'* ]]
		then
			if (( ${+precommand_options[$arg]} )) && _zsh_highlight_main__is_runnable $arg
			then
				style=precommand 
				() {
					set -- "${(@s.:.)precommand_options[$arg]}"
					flags_with_argument=$1 
					flags_sans_argument=$2 
					flags_solo=$3 
				}
				next_word=${next_word//:regular:/} 
				next_word+=':sudo_opt:' 
				next_word+=':start:' 
				if [[ $arg == 'exec' || $arg == 'env' ]]
				then
					next_word+=':regular:' 
				fi
			else
				case $res in
					(reserved) style=reserved-word 
						case $arg in
							(time|nocorrect) next_word=${next_word//:regular:/} 
								next_word+=':start:'  ;;
							($'\x7b') braces_stack='Y'"$braces_stack"  ;;
							($'\x7d') _zsh_highlight_main__stack_pop 'Y' reserved-word
								if [[ $style == reserved-word ]]
								then
									next_word+=':always:' 
								fi ;;
							($'\x5b\x5b') braces_stack='T'"$braces_stack"  ;;
							('do') braces_stack='D'"$braces_stack"  ;;
							('done') _zsh_highlight_main__stack_pop 'D' reserved-word ;;
							('if') braces_stack=':?'"$braces_stack"  ;;
							('then') _zsh_highlight_main__stack_pop ':' reserved-word ;;
							('elif') if [[ ${braces_stack[1]} == '?' ]]
								then
									braces_stack=':'"$braces_stack" 
								else
									style=unknown-token 
								fi ;;
							('else') if [[ ${braces_stack[1]} == '?' ]]
								then
									:
								else
									style=unknown-token 
								fi ;;
							('fi') _zsh_highlight_main__stack_pop '?' ;;
							('foreach') braces_stack='$'"$braces_stack"  ;;
							('end') _zsh_highlight_main__stack_pop '$' reserved-word ;;
							('repeat') in_redirection=2 
								this_word=':start::regular:'  ;;
							('!') if [[ $this_word != *':start_of_pipeline:'* ]]
								then
									style=unknown-token 
								else
									
								fi ;;
						esac
						if $saw_assignment && [[ $style != unknown-token ]]
						then
							style=unknown-token 
						fi ;;
					('suffix alias') style=suffix-alias  ;;
					('global alias') style=global-alias  ;;
					(alias) : ;;
					(builtin) style=builtin 
						[[ $arg == $'\x5b' ]] && braces_stack='Q'"$braces_stack"  ;;
					(function) style=function  ;;
					(command) style=command  ;;
					(hashed) style=hashed-command  ;;
					(none) if (( ! in_param )) && _zsh_highlight_main_highlighter_check_assign
						then
							_zsh_highlight_main_add_region_highlight $start_pos $end_pos assign
							local i=$(( arg[(i)=] + 1 )) 
							saw_assignment=true 
							if [[ $arg[i] == '(' ]]
							then
								in_array_assignment=true 
								_zsh_highlight_main_add_region_highlight start_pos+i-1 start_pos+i reserved-word
							else
								next_word+=':start:' 
								if (( i <= $#arg ))
								then
									() {
										local highlight_glob=false 
										[[ $zsyh_user_options[globassign] == on ]] && highlight_glob=true 
										_zsh_highlight_main_highlighter_highlight_argument $i
									}
								fi
							fi
							continue
						elif (( ! in_param )) && [[ $arg[0,1] = $histchars[0,1] ]] && (( $#arg[0,2] == 2 ))
						then
							style=history-expansion 
						elif (( ! in_param )) && [[ $arg[0,1] == $histchars[2,2] ]]
						then
							style=history-expansion 
						elif (( ! in_param )) && ! $saw_assignment && [[ $arg[1,2] == '((' ]]
						then
							_zsh_highlight_main_add_region_highlight $start_pos $((start_pos + 2)) reserved-word
							if [[ $arg[-2,-1] == '))' ]]
							then
								_zsh_highlight_main_add_region_highlight $((end_pos - 2)) $end_pos reserved-word
							fi
							continue
						elif (( ! in_param )) && [[ $arg == '()' ]]
						then
							style=reserved-word 
						elif (( ! in_param )) && ! $saw_assignment && [[ $arg == $'\x28' ]]
						then
							style=reserved-word 
							braces_stack='R'"$braces_stack" 
						elif (( ! in_param )) && [[ $arg == $'\x29' ]]
						then
							if _zsh_highlight_main__stack_pop 'S'
							then
								REPLY=$start_pos 
								reply=($list_highlights) 
								return 0
							fi
							_zsh_highlight_main__stack_pop 'R' reserved-word
						else
							if _zsh_highlight_main_highlighter_check_path $arg 1
							then
								style=$REPLY 
							else
								style=unknown-token 
							fi
						fi ;;
					(*) _zsh_highlight_main_add_region_highlight $start_pos $end_pos arg0_$res
						continue ;;
				esac
			fi
			if [[ -n ${(M)ZSH_HIGHLIGHT_TOKENS_CONTROL_FLOW:#"$arg"} ]]
			then
				next_word=':start::start_of_pipeline:' 
			fi
		elif _zsh_highlight_main__is_global_alias "$arg"
		then
			style=global-alias 
		else
			case $arg in
				($'\x29') if $in_array_assignment
					then
						_zsh_highlight_main_add_region_highlight $start_pos $end_pos assign
						_zsh_highlight_main_add_region_highlight $start_pos $end_pos reserved-word
						in_array_assignment=false 
						next_word+=':start:' 
						continue
					elif (( in_redirection ))
					then
						style=unknown-token 
					else
						if _zsh_highlight_main__stack_pop 'S'
						then
							REPLY=$start_pos 
							reply=($list_highlights) 
							return 0
						fi
						_zsh_highlight_main__stack_pop 'R' reserved-word
					fi ;;
				($'\x28\x29') if (( in_redirection )) || $in_array_assignment
					then
						style=unknown-token 
					else
						if [[ $zsyh_user_options[multifuncdef] == on ]] || false
						then
							next_word+=':start::start_of_pipeline:' 
						fi
						style=reserved-word 
					fi ;;
				(*) if false
					then
						
					elif [[ $arg = $'\x7d' ]] && $right_brace_is_recognised_everywhere
					then
						if (( in_redirection )) || $in_array_assignment
						then
							style=unknown-token 
						else
							_zsh_highlight_main__stack_pop 'Y' reserved-word
							if [[ $style == reserved-word ]]
							then
								next_word+=':always:' 
							fi
						fi
					elif [[ $arg[0,1] = $histchars[0,1] ]] && (( $#arg[0,2] == 2 ))
					then
						style=history-expansion 
					elif [[ $arg == $'\x5d\x5d' ]] && _zsh_highlight_main__stack_pop 'T' reserved-word
					then
						:
					elif [[ $arg == $'\x5d' ]] && _zsh_highlight_main__stack_pop 'Q' builtin
					then
						:
					else
						_zsh_highlight_main_highlighter_highlight_argument 1 $(( 1 != in_redirection ))
						continue
					fi ;;
			esac
		fi
		_zsh_highlight_main_add_region_highlight $start_pos $end_pos $style
	done
	(( $#in_alias )) && in_alias=() _zsh_highlight_main_add_region_highlight $start_pos $end_pos $alias_style
	(( in_param == 1 )) && in_param=0 _zsh_highlight_main_add_region_highlight $start_pos $end_pos $param_style
	[[ "$proc_buf" = (#b)(#s)(([[:space:]]|\\$'\n')#) ]]
	REPLY=$(( end_pos + ${#match[1]} - 1 )) 
	reply=($list_highlights) 
	return $(( $#braces_stack > 0 ))
}
_zsh_highlight_main_highlighter_highlight_path_separators () {
	local pos style_pathsep
	style_pathsep=$1_pathseparator 
	reply=() 
	[[ -z "$ZSH_HIGHLIGHT_STYLES[$style_pathsep]" || "$ZSH_HIGHLIGHT_STYLES[$1]" == "$ZSH_HIGHLIGHT_STYLES[$style_pathsep]" ]] && return 0
	for ((pos = start_pos; $pos <= end_pos; pos++ )) do
		if [[ $BUFFER[pos] == / ]]
		then
			reply+=($((pos - 1)) $pos $style_pathsep) 
		fi
	done
}
_zsh_highlight_main_highlighter_highlight_single_quote () {
	local arg1=$1 i q=\' style 
	i=$arg[(ib:arg1+1:)$q] 
	reply=() 
	if [[ $zsyh_user_options[rcquotes] == on ]]
	then
		while [[ $arg[i+1] == "'" ]]
		do
			reply+=($(( start_pos + i - 1 )) $(( start_pos + i + 1 )) rc-quote) 
			(( i++ ))
			i=$arg[(ib:i+1:)$q] 
		done
	fi
	if [[ $arg[i] == "'" ]]
	then
		style=single-quoted-argument 
	else
		(( i-- ))
		style=single-quoted-argument-unclosed 
	fi
	reply=($(( start_pos + arg1 - 1 )) $(( start_pos + i )) $style $reply) 
	REPLY=$i 
}
_zsh_highlight_pattern_highlighter_loop () {
	local buf="$1" pat="$2" 
	local -a match mbegin mend
	local MATCH
	integer MBEGIN MEND
	if [[ "$buf" == (#b)(*)(${~pat})* ]]
	then
		region_highlight+=("$((mbegin[2] - 1)) $mend[2] $ZSH_HIGHLIGHT_PATTERNS[$pat], memo=zsh-syntax-highlighting") 
		"$0" "$match[1]" "$pat"
		return $?
	fi
}
_zsh_highlight_preexec_hook () {
	typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER= 
	typeset -gi _ZSH_HIGHLIGHT_PRIOR_CURSOR= 
}
_zsh_highlight_regexp_highlighter_loop () {
	local buf="$1" pat="$2" 
	integer OFFSET=0 
	local MATCH
	integer MBEGIN MEND
	local -a match mbegin mend
	while true
	do
		[[ "$buf" =~ "$pat" ]] || return
		region_highlight+=("$((MBEGIN - 1 + OFFSET)) $((MEND + OFFSET)) $ZSH_HIGHLIGHT_REGEXP[$pat], memo=zsh-syntax-highlighting") 
		buf="$buf[$(($MEND+1)),-1]" 
		OFFSET=$((MEND+OFFSET)) 
	done
}
_zshz_chpwd () {
	ZSHZ[DIRECTORY_REMOVED]=0 
}
_zshz_precmd () {
	setopt LOCAL_OPTIONS UNSET
	[[ $PWD == "$HOME" ]] || (( ZSHZ[DIRECTORY_REMOVED] )) && return
	local exclude
	for exclude in ${(@)ZSHZ_EXCLUDE_DIRS:-${(@)_Z_EXCLUDE_DIRS}}
	do
		case $PWD in
			(${exclude} | ${exclude}/*) return ;;
		esac
	done
	if [[ $OSTYPE == (cygwin|msys) ]]
	then
		zshz --add "$PWD"
	else
		(
			zshz --add "$PWD" &
		)
	fi
	: $RANDOM
}
_zshz_usage () {
	print "Usage: ${ZSHZ_CMD:-${_Z_CMD:-z}} [OPTION]... [ARGUMENT]
Jump to a directory that you have visited frequently or recently, or a bit of both, based on the partial string ARGUMENT.

With no ARGUMENT, list the directory history in ascending rank.

  --add Add a directory to the database
  -c    Only match subdirectories of the current directory
  -e    Echo the best match without going to it
  -h    Display this help and exit
  -l    List all matches without going to them
  -r    Match by rank
  -t    Match by recent access
  -x    Remove a directory from the database (by default, the current directory)
  -xR   Remove a directory and its subdirectories from the database (by default, the current directory)" | fold -s -w $COLUMNS >&2
}
_zsocket () {
	# undefined
	builtin autoload -XUz
}
_zstyle () {
	# undefined
	builtin autoload -XUz
}
_ztodo () {
	# undefined
	builtin autoload -XUz
}
_zypper () {
	# undefined
	builtin autoload -XUz
}
add-zle-hook-widget () {
	# undefined
	builtin autoload -XU
}
add-zsh-hook () {
	emulate -L zsh
	local -a hooktypes
	hooktypes=(chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name) 
	local usage="Usage: add-zsh-hook hook function\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	if (( list ))
	then
		typeset -mp "(${1:-${(@j:|:)hooktypes}})_functions"
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local hook="${1}_functions" 
	local fn="$2" 
	if (( del ))
	then
		if (( ${(P)+hook} ))
		then
			if (( del == 2 ))
			then
				set -A $hook ${(P)hook:#${~fn}}
			else
				set -A $hook ${(P)hook:#$fn}
			fi
			if (( ! ${(P)#hook} ))
			then
				unset $hook
			fi
		fi
	else
		if (( ${(P)+hook} ))
		then
			if (( ${${(P)hook}[(I)$fn]} == 0 ))
			then
				typeset -ga $hook
				set -A $hook ${(P)hook} $fn
			fi
		else
			typeset -ga $hook
			set -A $hook $fn
		fi
		autoload $autoopts -- $fn
	fi
}
alias_value () {
	(( $+aliases[$1] )) && echo $aliases[$1]
}
azure_prompt_info () {
	return 1
}
bashcompinit () {
	# undefined
	builtin autoload -XUz
}
bracketed-paste-magic () {
	# undefined
	builtin autoload -XUz
}
bzr_prompt_info () {
	local bzr_branch
	bzr_branch=$(bzr nick 2>/dev/null)  || return
	if [[ -n "$bzr_branch" ]]
	then
		local bzr_dirty="" 
		if [[ -n $(bzr status 2>/dev/null) ]]
		then
			bzr_dirty=" %{$fg[red]%}*%{$reset_color%}" 
		fi
		printf "%s%s%s%s" "$ZSH_THEME_SCM_PROMPT_PREFIX" "bzr::${bzr_branch##*:}" "$bzr_dirty" "$ZSH_THEME_GIT_PROMPT_SUFFIX"
	fi
}
cbuild () {
	mkdir build 2> /dev/null
	cmake -B build
	cmake --build build
}
cgen () {
	if [ -d "$1" ]
	then
		echo "Directory \"$1\" already exists!"
		return 1
	fi
	nix flake new $1 --template /nix/store/wwd8mh9d15hhj7rk6m8gr9ym4qvfcqgn-source/dev-shells#c-cpp
	cd $1
	cat ~/.config/zsh/templates/ListTemplate.txt >> CMakeLists.txt
	mkdir src
	mkdir include
	cat ~/.config/zsh/templates/HelloWorldTemplate.txt >> src/main.cpp
	direnv allow
}
chruby_prompt_info () {
	return 1
}
clipcopy () {
	unfunction clipcopy clippaste
	detect-clipboard || true
	"$0" "$@"
}
clippaste () {
	unfunction clipcopy clippaste
	detect-clipboard || true
	"$0" "$@"
}
colors () {
	emulate -L zsh
	typeset -Ag color colour
	color=(00 none 01 bold 02 faint 22 normal 03 italic 23 no-italic 04 underline 24 no-underline 05 blink 25 no-blink 07 reverse 27 no-reverse 08 conceal 28 no-conceal 30 black 40 bg-black 31 red 41 bg-red 32 green 42 bg-green 33 yellow 43 bg-yellow 34 blue 44 bg-blue 35 magenta 45 bg-magenta 36 cyan 46 bg-cyan 37 white 47 bg-white 39 default 49 bg-default) 
	local k
	for k in ${(k)color}
	do
		color[${color[$k]}]=$k 
	done
	for k in ${color[(I)3?]}
	do
		color[fg-${color[$k]}]=$k 
	done
	for k in grey gray
	do
		color[$k]=${color[black]} 
		color[fg-$k]=${color[$k]} 
		color[bg-$k]=${color[bg-black]} 
	done
	colour=(${(kv)color}) 
	local lc=$'\e[' rc=m 
	typeset -Hg reset_color bold_color
	reset_color="$lc${color[none]}$rc" 
	bold_color="$lc${color[bold]}$rc" 
	typeset -AHg fg fg_bold fg_no_bold
	for k in ${(k)color[(I)fg-*]}
	do
		fg[${k#fg-}]="$lc${color[$k]}$rc" 
		fg_bold[${k#fg-}]="$lc${color[bold]};${color[$k]}$rc" 
		fg_no_bold[${k#fg-}]="$lc${color[normal]};${color[$k]}$rc" 
	done
	typeset -AHg bg bg_bold bg_no_bold
	for k in ${(k)color[(I)bg-*]}
	do
		bg[${k#bg-}]="$lc${color[$k]}$rc" 
		bg_bold[${k#bg-}]="$lc${color[bold]};${color[$k]}$rc" 
		bg_no_bold[${k#bg-}]="$lc${color[normal]};${color[$k]}$rc" 
	done
}
compaudit () {
	# undefined
	builtin autoload -XUz /etc/profiles/per-user/zak/share/zsh/5.9/functions
}
compdef () {
	local opt autol type func delete eval new i ret=0 cmd svc 
	local -a match mbegin mend
	emulate -L zsh
	setopt extendedglob
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	while getopts "anpPkKde" opt
	do
		case "$opt" in
			(a) autol=yes  ;;
			(n) new=yes  ;;
			([pPkK]) if [[ -n "$type" ]]
				then
					print -u2 "$0: type already set to $type"
					return 1
				fi
				if [[ "$opt" = p ]]
				then
					type=pattern 
				elif [[ "$opt" = P ]]
				then
					type=postpattern 
				elif [[ "$opt" = K ]]
				then
					type=widgetkey 
				else
					type=key 
				fi ;;
			(d) delete=yes  ;;
			(e) eval=yes  ;;
		esac
	done
	shift OPTIND-1
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	if [[ -z "$delete" ]]
	then
		if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
		then
			while (( $# ))
			do
				if [[ "$1" = *\=* ]]
				then
					cmd="${1%%\=*}" 
					svc="${1#*\=}" 
					func="$_comps[${_services[(r)$svc]:-$svc}]" 
					[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
					[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
					if [[ -n "$func" ]]
					then
						_comps[$cmd]="$func" 
						_services[$cmd]="$svc" 
					else
						print -u2 "$0: unknown command or service: $svc"
						ret=1 
					fi
				else
					print -u2 "$0: invalid argument: $1"
					ret=1 
				fi
				shift
			done
			return ret
		fi
		func="$1" 
		[[ -n "$autol" ]] && autoload -rUz "$func"
		shift
		case "$type" in
			(widgetkey) while [[ -n $1 ]]
				do
					if [[ $# -lt 3 ]]
					then
						print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
						return 1
					fi
					[[ $1 = _* ]] || 1="_$1" 
					[[ $2 = .* ]] || 2=".$2" 
					[[ $2 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$1" "$2" "$func"
					if [[ -n $new ]]
					then
						bindkey "$3" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
					else
						bindkey "$3" "$1"
					fi
					shift 3
				done ;;
			(key) if [[ $# -lt 2 ]]
				then
					print -u2 "$0: missing keys"
					return 1
				fi
				if [[ $1 = .* ]]
				then
					[[ $1 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" "$1" "$func"
				else
					[[ $1 = menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" ".$1" "$func"
				fi
				shift
				for i
				do
					if [[ -n $new ]]
					then
						bindkey "$i" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] || continue
					fi
					bindkey "$i" "$func"
				done ;;
			(*) while (( $# ))
				do
					if [[ "$1" = -N ]]
					then
						type=normal 
					elif [[ "$1" = -p ]]
					then
						type=pattern 
					elif [[ "$1" = -P ]]
					then
						type=postpattern 
					else
						case "$type" in
							(pattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_patcomps[$match[1]]="=$match[2]=$func" 
								else
									_patcomps[$1]="$func" 
								fi ;;
							(postpattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_postpatcomps[$match[1]]="=$match[2]=$func" 
								else
									_postpatcomps[$1]="$func" 
								fi ;;
							(*) if [[ "$1" = *\=* ]]
								then
									cmd="${1%%\=*}" 
									svc=yes 
								else
									cmd="$1" 
									svc= 
								fi
								if [[ -z "$new" || -z "${_comps[$1]}" ]]
								then
									_comps[$cmd]="$func" 
									[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
								fi ;;
						esac
					fi
					shift
				done ;;
		esac
	else
		case "$type" in
			(pattern) unset "_patcomps[$^@]" ;;
			(postpattern) unset "_postpatcomps[$^@]" ;;
			(key) print -u2 "$0: cannot restore key bindings"
				return 1 ;;
			(*) unset "_comps[$^@]" ;;
		esac
	fi
}
compdump () {
	# undefined
	builtin autoload -XUz /etc/profiles/per-user/zak/share/zsh/5.9/functions
}
compgen () {
	local opts prefix suffix job OPTARG OPTIND ret=1 
	local -a name res results jids
	local -A shortopts
	emulate -L sh
	setopt kshglob noshglob braceexpand nokshautoload
	shortopts=(a alias b builtin c command d directory e export f file g group j job k keyword u user v variable) 
	while getopts "o:A:G:C:F:P:S:W:X:abcdefgjkuv" name
	do
		case $name in
			([abcdefgjkuv]) OPTARG="${shortopts[$name]}"  ;&
			(A) case $OPTARG in
					(alias) results+=("${(k)aliases[@]}")  ;;
					(arrayvar) results+=("${(k@)parameters[(R)array*]}")  ;;
					(binding) results+=("${(k)widgets[@]}")  ;;
					(builtin) results+=("${(k)builtins[@]}" "${(k)dis_builtins[@]}")  ;;
					(command) results+=("${(k)commands[@]}" "${(k)aliases[@]}" "${(k)builtins[@]}" "${(k)functions[@]}" "${(k)reswords[@]}")  ;;
					(directory) setopt bareglobqual
						results+=(${IPREFIX}${PREFIX}*${SUFFIX}${ISUFFIX}(N-/)) 
						setopt nobareglobqual ;;
					(disabled) results+=("${(k)dis_builtins[@]}")  ;;
					(enabled) results+=("${(k)builtins[@]}")  ;;
					(export) results+=("${(k)parameters[(R)*export*]}")  ;;
					(file) setopt bareglobqual
						results+=(${IPREFIX}${PREFIX}*${SUFFIX}${ISUFFIX}(N)) 
						setopt nobareglobqual ;;
					(function) results+=("${(k)functions[@]}")  ;;
					(group) emulate zsh
						_groups -U -O res
						emulate sh
						setopt kshglob noshglob braceexpand
						results+=("${res[@]}")  ;;
					(hostname) emulate zsh
						_hosts -U -O res
						emulate sh
						setopt kshglob noshglob braceexpand
						results+=("${res[@]}")  ;;
					(job) results+=("${savejobtexts[@]%% *}")  ;;
					(keyword) results+=("${(k)reswords[@]}")  ;;
					(running) jids=("${(@k)savejobstates[(R)running*]}") 
						for job in "${jids[@]}"
						do
							results+=(${savejobtexts[$job]%% *}) 
						done ;;
					(stopped) jids=("${(@k)savejobstates[(R)suspended*]}") 
						for job in "${jids[@]}"
						do
							results+=(${savejobtexts[$job]%% *}) 
						done ;;
					(setopt | shopt) results+=("${(k)options[@]}")  ;;
					(signal) results+=("SIG${^signals[@]}")  ;;
					(user) results+=("${(k)userdirs[@]}")  ;;
					(variable) results+=("${(k)parameters[@]}")  ;;
					(helptopic)  ;;
				esac ;;
			(F) COMPREPLY=() 
				local -a args
				args=("${words[0]}" "${@[-1]}" "${words[CURRENT-2]}") 
				() {
					typeset -h words
					$OPTARG "${args[@]}"
				}
				results+=("${COMPREPLY[@]}")  ;;
			(G) setopt nullglob
				results+=(${~OPTARG}) 
				unsetopt nullglob ;;
			(W) results+=(${(Q)~=OPTARG})  ;;
			(C) results+=($(eval $OPTARG))  ;;
			(P) prefix="$OPTARG"  ;;
			(S) suffix="$OPTARG"  ;;
			(X) if [[ ${OPTARG[0]} = '!' ]]
				then
					results=("${(M)results[@]:#${OPTARG#?}}") 
				else
					results=("${results[@]:#$OPTARG}") 
				fi ;;
		esac
	done
	print -l -r -- "$prefix${^results[@]}$suffix"
}
compinit () {
	# undefined
	builtin autoload -XUz /etc/profiles/per-user/zak/share/zsh/5.9/functions
}
compinstall () {
	# undefined
	builtin autoload -XUz /etc/profiles/per-user/zak/share/zsh/5.9/functions
}
complete () {
	emulate -L zsh
	local args void cmd print remove
	args=("$@") 
	zparseopts -D -a void o: A: G: W: C: F: P: S: X: a b c d e f g j k u v p=print r=remove
	if [[ -n $print ]]
	then
		printf 'complete %2$s %1$s\n' "${(@kv)_comps[(R)_bash*]#* }"
	elif [[ -n $remove ]]
	then
		for cmd
		do
			unset "_comps[$cmd]"
		done
	else
		compdef _bash_complete\ ${(j. .)${(q)args[1,-1-$#]}} "$@"
	fi
}
conda_prompt_info () {
	return 1
}
crun () {
	mkdir build 2> /dev/null
	cmake -B build
	cmake --build build
	build/main
}
d () {
	if [[ -n $1 ]]
	then
		dirs "$@"
	else
		dirs -v | head -n 10
	fi
}
default () {
	(( $+parameters[$1] )) && return 0
	typeset -g "$1"="$2" && return 3
}
detect-clipboard () {
	emulate -L zsh
	if [[ "${OSTYPE}" == darwin* ]] && (( ${+commands[pbcopy]} )) && (( ${+commands[pbpaste]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | pbcopy
		}
		clippaste () {
			pbpaste
		}
	elif [[ "${OSTYPE}" == (cygwin|msys)* ]]
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" > /dev/clipboard
		}
		clippaste () {
			cat /dev/clipboard
		}
	elif (( $+commands[clip.exe] )) && (( $+commands[powershell.exe] ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | clip.exe
		}
		clippaste () {
			powershell.exe -noprofile -command Get-Clipboard
		}
	elif [ -n "${WAYLAND_DISPLAY:-}" ] && (( ${+commands[wl-copy]} )) && (( ${+commands[wl-paste]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | wl-copy &> /dev/null &|
		}
		clippaste () {
			wl-paste --no-newline
		}
	elif [ -n "${DISPLAY:-}" ] && (( ${+commands[xsel]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | xsel --clipboard --input
		}
		clippaste () {
			xsel --clipboard --output
		}
	elif [ -n "${DISPLAY:-}" ] && (( ${+commands[xclip]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | xclip -selection clipboard -in &> /dev/null &|
		}
		clippaste () {
			xclip -out -selection clipboard
		}
	elif (( ${+commands[lemonade]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | lemonade copy
		}
		clippaste () {
			lemonade paste
		}
	elif (( ${+commands[doitclient]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | doitclient wclip
		}
		clippaste () {
			doitclient wclip -r
		}
	elif (( ${+commands[win32yank]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | win32yank -i
		}
		clippaste () {
			win32yank -o
		}
	elif [[ $OSTYPE == linux-android* ]] && (( $+commands[termux-clipboard-set] ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | termux-clipboard-set
		}
		clippaste () {
			termux-clipboard-get
		}
	elif [ -n "${TMUX:-}" ] && (( ${+commands[tmux]} ))
	then
		clipcopy () {
			tmux load-buffer -w "${1:--}"
		}
		clippaste () {
			tmux save-buffer -
		}
	else
		_retry_clipboard_detection_or_fail () {
			local clipcmd="${1}" 
			shift
			if detect-clipboard
			then
				"${clipcmd}" "$@"
			else
				print "${clipcmd}: Platform $OSTYPE not supported or xclip/xsel not installed" >&2
				return 1
			fi
		}
		clipcopy () {
			_retry_clipboard_detection_or_fail clipcopy "$@"
		}
		clippaste () {
			_retry_clipboard_detection_or_fail clippaste "$@"
		}
		return 1
	fi
}
diff () {
	command diff --color "$@"
}
down-line-or-beginning-search () {
	# undefined
	builtin autoload -XU
}
edit-command-line () {
	# undefined
	builtin autoload -XU
}
env_default () {
	[[ ${parameters[$1]} = *-export* ]] && return 0
	export "$1=$2" && return 3
}
ex () {
	if [ -z "$1" ]
	then
		echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
		echo "       extract <path/file_name_1.ext> [path/file_name_2.ext] [path/file_name_3.ext]"
	else
		for n in "$@"
		do
			if [ -f "$n" ]
			then
				case "${n%,}" in
					(*.cbt | *.tar.bz2 | *.tar.gz | *.tar.xz | *.tbz2 | *.tgz | *.txz | *.tar) /nix/store/isva9q9zx3frx6hh6cnpihh1kd2bx6bk-gnutar-1.35/bin/tar xvf "$n" ;;
					(*.lzma) unlzma ./"$n" ;;
					(*.bz2) bunzip2 ./"$n" ;;
					(*.cbr | *.rar) unrar x -ad ./"$n" ;;
					(*.gz) gunzip ./"$n" ;;
					(*.cbz | *.epub | *.zip) unzip ./"$n" ;;
					(*.z) uncompress ./"$n" ;;
					(*.7z | *.arj | *.cab | *.cb7 | *.chm | *.deb | *.dmg | *.iso | *.lzh | *.msi | *.pkg | *.rpm | *.udf | *.wim | *.xar) /nix/store/4qrrm8bznjpzzj3qkladxgx4pp07axmz-p7zip-17.06/bin/7z x ./"$n" ;;
					(*.xz) unxz ./"$n" ;;
					(*.exe) cabextract ./"$n" ;;
					(*.cpio) cpio -id < ./"$n" ;;
					(*.cba | *.ace) unace x ./"$n" ;;
					(*) echo "Unsupported format"
						return 1 ;;
				esac
			else
				echo "'$n' - file does not exist"
				return 1
			fi
		done
	fi
}
finit () {
	nix flake init --template /nix/store/wwd8mh9d15hhj7rk6m8gr9ym4qvfcqgn-source/dev-shells#$1
	direnv allow
}
fnew () {
	if [ -d "$1" ]
	then
		echo "Directory \"$1\" already exists!"
		return 1
	fi
	nix flake new $1 --template /nix/store/wwd8mh9d15hhj7rk6m8gr9ym4qvfcqgn-source/dev-shells#$2
	cd $1
	direnv allow
}
gbda () {
	git branch --no-color --merged | command grep -vE "^([+*]|\s*($(git_main_branch)|$(git_develop_branch))\s*$)" | command xargs git branch --delete 2> /dev/null
}
gbds () {
	local default_branch=$(git_main_branch) 
	(( ! $? )) || default_branch=$(git_develop_branch) 
	git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch
	do
		local merge_base=$(git merge-base $default_branch $branch) 
		if [[ $(git cherry $default_branch $(git commit-tree $(git rev-parse $branch\^{tree}) -p $merge_base -m _)) = -* ]]
		then
			git branch -D $branch
		fi
	done
}
gccd () {
	setopt localoptions extendedglob
	local repo="${${@[(r)(ssh://*|git://*|ftp(s)#://*|http(s)#://*|*@*)(.git/#)#]}:-$_}" 
	command git clone --recurse-submodules "$@" || return
	[[ -d "$_" ]] && cd "$_" || cd "${${repo:t}%.git/#}"
}
gdnolock () {
	git diff "$@" ":(exclude)package-lock.json" ":(exclude)*.lock"
}
gdv () {
	git diff -w "$@" | view -
}
getColorCode () {
	eval "$__p9k_intro"
	if (( ARGC == 1 ))
	then
		case $1 in
			(foreground) local k
				for k in "${(k@)__p9k_colors}"
				do
					local v=${__p9k_colors[$k]} 
					print -rP -- "%F{$v}$v - $k%f"
				done
				return 0 ;;
			(background) local k
				for k in "${(k@)__p9k_colors}"
				do
					local v=${__p9k_colors[$k]} 
					print -rP -- "%K{$v}$v - $k%k"
				done
				return 0 ;;
		esac
	fi
	echo "Usage: getColorCode background|foreground" >&2
	return 1
}
get_icon_names () {
	eval "$__p9k_intro"
	_p9k_init_icons
	local key
	for key in ${(@kon)icons}
	do
		echo -n - "POWERLEVEL9K_$key: "
		print -nP "%K{red} %k"
		if [[ $1 == original ]]
		then
			echo -n - $icons[$key]
		else
			print_icon $key
		fi
		print -P "%K{red} %k"
	done
}
ggf () {
	local b
	[[ $# != 1 ]] && b="$(git_current_branch)" 
	git push --force origin "${b:-$1}"
}
ggfl () {
	local b
	[[ $# != 1 ]] && b="$(git_current_branch)" 
	git push --force-with-lease origin "${b:-$1}"
}
ggl () {
	if [[ $# != 0 ]] && [[ $# != 1 ]]
	then
		git pull origin "${*}"
	else
		local b
		[[ $# == 0 ]] && b="$(git_current_branch)" 
		git pull origin "${b:-$1}"
	fi
}
ggp () {
	if [[ $# != 0 ]] && [[ $# != 1 ]]
	then
		git push origin "${*}"
	else
		local b
		[[ $# == 0 ]] && b="$(git_current_branch)" 
		git push origin "${b:-$1}"
	fi
}
ggpnp () {
	if [[ $# == 0 ]]
	then
		ggl && ggp
	else
		ggl "${*}" && ggp "${*}"
	fi
}
ggu () {
	local b
	[[ $# != 1 ]] && b="$(git_current_branch)" 
	git pull --rebase origin "${b:-$1}"
}
gi () {
	local query="${(j:,:)@}" 
	_gi_curl "$query" || return 1
}
git_commits_ahead () {
	if __git_prompt_git rev-parse --git-dir &> /dev/null
	then
		local commits="$(__git_prompt_git rev-list --count @{upstream}..HEAD 2>/dev/null)" 
		if [[ -n "$commits" && "$commits" != 0 ]]
		then
			echo "$ZSH_THEME_GIT_COMMITS_AHEAD_PREFIX$commits$ZSH_THEME_GIT_COMMITS_AHEAD_SUFFIX"
		fi
	fi
}
git_commits_behind () {
	if __git_prompt_git rev-parse --git-dir &> /dev/null
	then
		local commits="$(__git_prompt_git rev-list --count HEAD..@{upstream} 2>/dev/null)" 
		if [[ -n "$commits" && "$commits" != 0 ]]
		then
			echo "$ZSH_THEME_GIT_COMMITS_BEHIND_PREFIX$commits$ZSH_THEME_GIT_COMMITS_BEHIND_SUFFIX"
		fi
	fi
}
git_current_branch () {
	local ref
	ref=$(__git_prompt_git symbolic-ref --quiet HEAD 2> /dev/null) 
	local ret=$? 
	if [[ $ret != 0 ]]
	then
		[[ $ret == 128 ]] && return
		ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  || return
	fi
	echo ${ref#refs/heads/}
}
git_current_user_email () {
	__git_prompt_git config user.email 2> /dev/null
}
git_current_user_name () {
	__git_prompt_git config user.name 2> /dev/null
}
git_develop_branch () {
	command git rev-parse --git-dir &> /dev/null || return
	local branch
	for branch in dev devel develop development
	do
		if command git show-ref -q --verify refs/heads/$branch
		then
			echo $branch
			return 0
		fi
	done
	echo develop
	return 1
}
git_main_branch () {
	command git rev-parse --git-dir &> /dev/null || return
	local remote ref
	for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}
	do
		if command git show-ref -q --verify $ref
		then
			echo ${ref:t}
			return 0
		fi
	done
	for remote in origin upstream
	do
		ref=$(command git rev-parse --abbrev-ref $remote/HEAD 2>/dev/null) 
		if [[ $ref == $remote/* ]]
		then
			echo ${ref#"$remote/"}
			return 0
		fi
	done
	echo master
	return 1
}
git_previous_branch () {
	local ref
	ref=$(__git_prompt_git rev-parse --quiet --symbolic-full-name @{-1} 2> /dev/null) 
	local ret=$? 
	if [[ $ret != 0 ]] || [[ -z $ref ]]
	then
		return
	fi
	echo ${ref#refs/heads/}
}
git_prompt_ahead () {
	if [[ -n "$(__git_prompt_git rev-list origin/$(git_current_branch)..HEAD 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_AHEAD"
	fi
}
git_prompt_behind () {
	if [[ -n "$(__git_prompt_git rev-list HEAD..origin/$(git_current_branch) 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_BEHIND"
	fi
}
git_prompt_info () {
	if [[ -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_info]}" ]]
	then
		echo -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_info]}"
	fi
}
git_prompt_long_sha () {
	local SHA
	SHA=$(__git_prompt_git rev-parse HEAD 2> /dev/null)  && echo "$ZSH_THEME_GIT_PROMPT_SHA_BEFORE$SHA$ZSH_THEME_GIT_PROMPT_SHA_AFTER"
}
git_prompt_remote () {
	if [[ -n "$(__git_prompt_git show-ref origin/$(git_current_branch) 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_REMOTE_EXISTS"
	else
		echo "$ZSH_THEME_GIT_PROMPT_REMOTE_MISSING"
	fi
}
git_prompt_short_sha () {
	local SHA
	SHA=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  && echo "$ZSH_THEME_GIT_PROMPT_SHA_BEFORE$SHA$ZSH_THEME_GIT_PROMPT_SHA_AFTER"
}
git_prompt_status () {
	if [[ -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_status]}" ]]
	then
		echo -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_status]}"
	fi
}
git_remote_status () {
	local remote ahead behind git_remote_status git_remote_status_detailed
	remote=${$(__git_prompt_git rev-parse --verify ${hook_com[branch]}@{upstream} --symbolic-full-name 2>/dev/null)/refs\/remotes\/} 
	if [[ -n ${remote} ]]
	then
		ahead=$(__git_prompt_git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l) 
		behind=$(__git_prompt_git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l) 
		if [[ $ahead -eq 0 ]] && [[ $behind -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_EQUAL_REMOTE" 
		elif [[ $ahead -gt 0 ]] && [[ $behind -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE$((ahead))%{$reset_color%}" 
		elif [[ $behind -gt 0 ]] && [[ $ahead -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE$((behind))%{$reset_color%}" 
		elif [[ $ahead -gt 0 ]] && [[ $behind -gt 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_DIVERGED_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE$((ahead))%{$reset_color%}$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE$((behind))%{$reset_color%}" 
		fi
		if [[ -n $ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_DETAILED ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_PREFIX${remote:gs/%/%%}$git_remote_status_detailed$ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_SUFFIX" 
		fi
		echo $git_remote_status
	fi
}
git_repo_name () {
	local repo_path
	if repo_path="$(__git_prompt_git rev-parse --show-toplevel 2>/dev/null)"  && [[ -n "$repo_path" ]]
	then
		echo ${repo_path:t}
	fi
}
grename () {
	if [[ -z "$1" || -z "$2" ]]
	then
		echo "Usage: $0 old_branch new_branch"
		return 1
	fi
	git branch -m "$1" "$2"
	if git push origin :"$1"
	then
		git push --set-upstream origin "$2"
	fi
}
gunwipall () {
	local _commit=$(git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H) 
	if [[ "$_commit" != "$(git rev-parse HEAD)" ]]
	then
		git reset $_commit || return 1
	fi
}
handle_completion_insecurities () {
	local -aU insecure_dirs
	insecure_dirs=(${(f@):-"$(compaudit 2>/dev/null)"}) 
	[[ -z "${insecure_dirs}" ]] && return
	print "[oh-my-zsh] Insecure completion-dependent directories detected:"
	ls -ld "${(@)insecure_dirs}"
	cat <<EOD

[oh-my-zsh] For safety, we will not load completions from these directories until
[oh-my-zsh] you fix their permissions and ownership and restart zsh.
[oh-my-zsh] See the above list for directories with group or other writability.

[oh-my-zsh] To fix your permissions you can do so by disabling
[oh-my-zsh] the write permission of "group" and "others" and making sure that the
[oh-my-zsh] owner of these directories is either root or your current user.
[oh-my-zsh] The following command may help:
[oh-my-zsh]     compaudit | xargs chmod g-w,o-w

[oh-my-zsh] If the above didn't help or you want to skip the verification of
[oh-my-zsh] insecure directories you can set the variable ZSH_DISABLE_COMPFIX to
[oh-my-zsh] "true" before oh-my-zsh is sourced in your zshrc file.

EOD
}
hg_prompt_info () {
	return 1
}
instant_prompt__p9k_internal_nothing () {
	prompt__p9k_internal_nothing
}
instant_prompt_chezmoi_shell () {
	_p9k_prompt_segment prompt_chezmoi_shell blue $_p9k_color1 CHEZMOI_ICON 1 '$CHEZMOI_ICON' ''
}
instant_prompt_context () {
	if [[ $_POWERLEVEL9K_ALWAYS_SHOW_CONTEXT == 0 && -n $DEFAULT_USER && $P9K_SSH == 0 ]]
	then
		if [[ ${(%):-%n} == $DEFAULT_USER ]]
		then
			if (( ! _POWERLEVEL9K_ALWAYS_SHOW_USER ))
			then
				return
			fi
		fi
	fi
	prompt_context
}
instant_prompt_date () {
	_p9k_escape $_POWERLEVEL9K_DATE_FORMAT
	local stash='${${__p9k_instant_prompt_date::=${(%)${__p9k_instant_prompt_date_format::='$_p9k__ret'}}}+}' 
	_p9k_escape $_POWERLEVEL9K_DATE_FORMAT
	_p9k_prompt_segment prompt_date "$_p9k_color2" "$_p9k_color1" "DATE_ICON" 1 '' $stash$_p9k__ret
}
instant_prompt_dir () {
	prompt_dir
}
instant_prompt_dir_writable () {
	prompt_dir_writable
}
instant_prompt_direnv () {
	if [[ -n ${DIRENV_DIR:-} && $precmd_functions[-1] == _p9k_precmd ]]
	then
		_p9k_prompt_segment prompt_direnv $_p9k_color1 yellow DIRENV_ICON 0 '' ''
	fi
}
instant_prompt_host () {
	prompt_host
}
instant_prompt_lf () {
	_p9k_prompt_segment prompt_lf 6 $_p9k_color1 LF_ICON 1 '${LF_LEVEL:#0}' '$LF_LEVEL'
}
instant_prompt_midnight_commander () {
	_p9k_prompt_segment prompt_midnight_commander $_p9k_color1 yellow MIDNIGHT_COMMANDER_ICON 0 '$MC_TMPDIR' ''
}
instant_prompt_nix_shell () {
	_p9k_prompt_segment prompt_nix_shell 4 $_p9k_color1 NIX_SHELL_ICON 1 "$_p9k_nix_shell_cond" '${(M)IN_NIX_SHELL:#(pure|impure)}'
}
instant_prompt_nnn () {
	_p9k_prompt_segment prompt_nnn 6 $_p9k_color1 NNN_ICON 1 '${NNNLVL:#0}' '$NNNLVL'
}
instant_prompt_os_icon () {
	prompt_os_icon
}
instant_prompt_per_directory_history () {
	case $HISTORY_START_WITH_GLOBAL in
		(true) _p9k_prompt_segment prompt_per_directory_history_GLOBAL 3 $_p9k_color1 HISTORY_ICON 0 '' global ;;
		(?*) _p9k_prompt_segment prompt_per_directory_history_LOCAL 5 $_p9k_color1 HISTORY_ICON 0 '' local ;;
	esac
}
instant_prompt_prompt_char () {
	_p9k_prompt_segment prompt_prompt_char_OK_VIINS "$_p9k_color1" 76 '' 0 '' '❯'
}
instant_prompt_ranger () {
	_p9k_prompt_segment prompt_ranger $_p9k_color1 yellow RANGER_ICON 1 '$RANGER_LEVEL' '$RANGER_LEVEL'
}
instant_prompt_root_indicator () {
	prompt_root_indicator
}
instant_prompt_ssh () {
	if (( ! P9K_SSH ))
	then
		return
	fi
	prompt_ssh
}
instant_prompt_status () {
	if (( _POWERLEVEL9K_STATUS_OK ))
	then
		_p9k_prompt_segment prompt_status_OK "$_p9k_color1" green OK_ICON 0 '' ''
	fi
}
instant_prompt_time () {
	_p9k_escape $_POWERLEVEL9K_TIME_FORMAT
	local stash='${${__p9k_instant_prompt_time::=${(%)${__p9k_instant_prompt_time_format::='$_p9k__ret'}}}+}' 
	_p9k_escape $_POWERLEVEL9K_TIME_FORMAT
	_p9k_prompt_segment prompt_time "$_p9k_color2" "$_p9k_color1" "TIME_ICON" 1 '' $stash$_p9k__ret
}
instant_prompt_toolbox () {
	_p9k_prompt_segment prompt_toolbox $_p9k_color1 yellow TOOLBOX_ICON 1 '$P9K_TOOLBOX_NAME' '$P9K_TOOLBOX_NAME'
}
instant_prompt_user () {
	if [[ $_POWERLEVEL9K_ALWAYS_SHOW_USER == 0 && "${(%):-%n}" == $DEFAULT_USER ]]
	then
		return
	fi
	prompt_user
}
instant_prompt_vi_mode () {
	if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
	then
		_p9k_prompt_segment prompt_vi_mode_INSERT "$_p9k_color1" blue '' 0 '' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
	fi
}
instant_prompt_vim_shell () {
	_p9k_prompt_segment prompt_vim_shell green $_p9k_color1 VIM_ICON 0 '$VIMRUNTIME' ''
}
instant_prompt_xplr () {
	_p9k_prompt_segment prompt_xplr 6 $_p9k_color1 XPLR_ICON 0 '$XPLR_PID' ''
}
instant_prompt_yazi () {
	_p9k_prompt_segment prompt_yazi $_p9k_color1 yellow YAZI_ICON 1 '$YAZI_LEVEL' '$YAZI_LEVEL'
}
is-at-least () {
	emulate -L zsh
	local IFS=".-" min_cnt=0 ver_cnt=0 part min_ver version order 
	min_ver=(${=1}) 
	version=(${=2:-$ZSH_VERSION} 0) 
	while (( $min_cnt <= ${#min_ver} ))
	do
		while [[ "$part" != <-> ]]
		do
			(( ++ver_cnt > ${#version} )) && return 0
			if [[ ${version[ver_cnt]} = *[0-9][^0-9]* ]]
			then
				order=(${version[ver_cnt]} ${min_ver[ver_cnt]}) 
				if [[ ${version[ver_cnt]} = <->* ]]
				then
					[[ $order != ${${(On)order}} ]] && return 1
				else
					[[ $order != ${${(O)order}} ]] && return 1
				fi
				[[ $order[1] != $order[2] ]] && return 0
			fi
			part=${version[ver_cnt]##*[^0-9]} 
		done
		while true
		do
			(( ++min_cnt > ${#min_ver} )) && return 0
			[[ ${min_ver[min_cnt]} = <-> ]] && break
		done
		(( part > min_ver[min_cnt] )) && return 0
		(( part < min_ver[min_cnt] )) && return 1
		part='' 
	done
}
is_plugin () {
	local base_dir=$1 
	local name=$2 
	builtin test -f $base_dir/plugins/$name/$name.plugin.zsh || builtin test -f $base_dir/plugins/$name/_$name
}
is_theme () {
	local base_dir=$1 
	local name=$2 
	builtin test -f $base_dir/$name.zsh-theme
}
jenv_prompt_info () {
	return 1
}
lf () {
	tmp="$(mktemp)" 
	command lf -last-dir-path="$tmp" "$@"
	if [ -f "$tmp" ]
	then
		dir="$(cat "$tmp")" 
		rm -f "$tmp"
		if [ -d "$dir" ]
		then
			if [ "$dir" != "$(pwd)" ]
			then
				cd "$dir"
			fi
		fi
	fi
}
lg () {
	export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir 
	command lazygit "$@"
	if [ -f $LAZYGIT_NEW_DIR_FILE ]
	then
		cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
		rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
	fi
}
mkcd () {
	mkdir -p $@ && cd ${@:$#}
}
nvm_prompt_info () {
	which nvm &> /dev/null || return
	local nvm_prompt=${$(nvm current)#v} 
	echo "${ZSH_THEME_NVM_PROMPT_PREFIX}${nvm_prompt:gs/%/%%}${ZSH_THEME_NVM_PROMPT_SUFFIX}"
}
omz () {
	setopt localoptions noksharrays
	[[ $# -gt 0 ]] || {
		_omz::help
		return 1
	}
	local command="$1" 
	shift
	(( ${+functions[_omz::$command]} )) || {
		_omz::help
		return 1
	}
	_omz::$command "$@"
}
omz_diagnostic_dump () {
	emulate -L zsh
	builtin echo "Generating diagnostic dump; please be patient..."
	local thisfcn=omz_diagnostic_dump 
	local -A opts
	local opt_verbose opt_noverbose opt_outfile
	local timestamp=$(date +%Y%m%d-%H%M%S) 
	local outfile=omz_diagdump_$timestamp.txt 
	builtin zparseopts -A opts -D -- "v+=opt_verbose" "V+=opt_noverbose"
	local verbose n_verbose=${#opt_verbose} n_noverbose=${#opt_noverbose} 
	(( verbose = 1 + n_verbose - n_noverbose ))
	if [[ ${#*} > 0 ]]
	then
		opt_outfile=$1 
	fi
	if [[ ${#*} > 1 ]]
	then
		builtin echo "$thisfcn: error: too many arguments" >&2
		return 1
	fi
	if [[ -n "$opt_outfile" ]]
	then
		outfile="$opt_outfile" 
	fi
	_omz_diag_dump_one_big_text &> "$outfile"
	if [[ $? != 0 ]]
	then
		builtin echo "$thisfcn: error while creating diagnostic dump; see $outfile for details"
	fi
	builtin echo
	builtin echo Diagnostic dump file created at: "$outfile"
	builtin echo
	builtin echo To share this with OMZ developers, post it as a gist on GitHub
	builtin echo at "https://gist.github.com" and share the link to the gist.
	builtin echo
	builtin echo "WARNING: This dump file contains all your zsh and omz configuration files,"
	builtin echo "so don't share it publicly if there's sensitive information in them."
	builtin echo
}
omz_history () {
	local clear list stamp REPLY
	zparseopts -E -D c=clear l=list f=stamp E=stamp i=stamp t:=stamp
	if [[ -n "$clear" ]]
	then
		print -nu2 "This action will irreversibly delete your command history. Are you sure? [y/N] "
		builtin read -E
		[[ "$REPLY" = [yY] ]] || return 0
		print -nu2 >| "$HISTFILE"
		fc -p "$HISTFILE"
		print -u2 History file deleted.
	elif [[ $# -eq 0 ]]
	then
		builtin fc "${stamp[@]}" -l 1
	else
		builtin fc "${stamp[@]}" -l "$@"
	fi
}
omz_termsupport_cwd () {
	setopt localoptions unset
	local URL_HOST URL_PATH
	URL_HOST="$(omz_urlencode -P $HOST)"  || return 1
	URL_PATH="$(omz_urlencode -P $PWD)"  || return 1
	[[ -z "$KONSOLE_PROFILE_NAME" && -z "$KONSOLE_DBUS_SESSION" ]] || URL_HOST="" 
	printf "\e]7;file://%s%s\e\\" "${URL_HOST}" "${URL_PATH}"
}
omz_termsupport_precmd () {
	[[ "${DISABLE_AUTO_TITLE:-}" != true ]] || return 0
	title "$ZSH_THEME_TERM_TAB_TITLE_IDLE" "$ZSH_THEME_TERM_TITLE_IDLE"
}
omz_termsupport_preexec () {
	[[ "${DISABLE_AUTO_TITLE:-}" != true ]] || return 0
	emulate -L zsh
	setopt extended_glob
	local -a cmdargs
	cmdargs=("${(z)2}") 
	if [[ "${cmdargs[1]}" = fg ]]
	then
		local job_id jobspec="${cmdargs[2]#%}" 
		case "$jobspec" in
			(<->) job_id=${jobspec}  ;;
			("" | % | +) job_id=${(k)jobstates[(r)*:+:*]}  ;;
			(-) job_id=${(k)jobstates[(r)*:-:*]}  ;;
			([?]*) job_id=${(k)jobtexts[(r)*${(Q)jobspec}*]}  ;;
			(*) job_id=${(k)jobtexts[(r)${(Q)jobspec}*]}  ;;
		esac
		if [[ -n "${jobtexts[$job_id]}" ]]
		then
			1="${jobtexts[$job_id]}" 
			2="${jobtexts[$job_id]}" 
		fi
	fi
	local CMD="${1[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}" 
	local LINE="${2:gs/%/%%}" 
	title "$CMD" "%100>...>${LINE}%<<"
}
omz_urldecode () {
	emulate -L zsh
	local encoded_url=$1 
	local caller_encoding=$langinfo[CODESET] 
	local LC_ALL=C 
	export LC_ALL
	local tmp=${encoded_url:gs/+/ /} 
	tmp=${tmp:gs/\\/\\\\/} 
	tmp=${tmp:gs/%/\\x/} 
	local decoded="$(printf -- "$tmp")" 
	local -a safe_encodings
	safe_encodings=(UTF-8 utf8 US-ASCII) 
	if [[ -z ${safe_encodings[(r)$caller_encoding]} ]]
	then
		decoded=$(echo -E "$decoded" | iconv -f UTF-8 -t $caller_encoding) 
		if [[ $? != 0 ]]
		then
			echo "Error converting string from UTF-8 to $caller_encoding" >&2
			return 1
		fi
	fi
	echo -E "$decoded"
}
omz_urlencode () {
	emulate -L zsh
	setopt norematchpcre
	local -a opts
	zparseopts -D -E -a opts r m P
	local in_str="$@" 
	local url_str="" 
	local spaces_as_plus
	if [[ -z $opts[(r)-P] ]]
	then
		spaces_as_plus=1 
	fi
	local str="$in_str" 
	local encoding=$langinfo[CODESET] 
	local safe_encodings
	safe_encodings=(UTF-8 utf8 US-ASCII) 
	if [[ -z ${safe_encodings[(r)$encoding]} ]]
	then
		str=$(echo -E "$str" | iconv -f $encoding -t UTF-8) 
		if [[ $? != 0 ]]
		then
			echo "Error converting string from $encoding to UTF-8" >&2
			return 1
		fi
	fi
	local i byte ord LC_ALL=C 
	export LC_ALL
	local reserved=';/?:@&=+$,' 
	local mark='_.!~*''()-' 
	local dont_escape="[A-Za-z0-9" 
	if [[ -z $opts[(r)-r] ]]
	then
		dont_escape+=$reserved 
	fi
	if [[ -z $opts[(r)-m] ]]
	then
		dont_escape+=$mark 
	fi
	dont_escape+="]" 
	local url_str="" 
	for ((i = 1; i <= ${#str}; ++i )) do
		byte="$str[i]" 
		if [[ "$byte" =~ "$dont_escape" ]]
		then
			url_str+="$byte" 
		else
			if [[ "$byte" == " " && -n $spaces_as_plus ]]
			then
				url_str+="+" 
			elif [[ "$PREFIX" = *com.termux* ]]
			then
				url_str+="$byte" 
			else
				ord=$(( [##16] #byte )) 
				url_str+="%$ord" 
			fi
		fi
	done
	echo -E "$url_str"
}
open_command () {
	local open_cmd
	case "$OSTYPE" in
		(darwin*) open_cmd='open'  ;;
		(cygwin*) open_cmd='cygstart'  ;;
		(linux*) [[ "$(uname -r)" != *icrosoft* ]] && open_cmd='nohup xdg-open'  || {
				open_cmd='cmd.exe /c start ""' 
				[[ -e "$1" ]] && {
					1="$(wslpath -w "${1:a}")"  || return 1
				}
				[[ "$1" = (http|https)://* ]] && {
					1="$(echo "$1" | sed -E 's/([&|()<>^])/^\1/g')"  || return 1
				}
			} ;;
		(msys*) open_cmd='start ""'  ;;
		(*) echo "Platform $OSTYPE not supported"
			return 1 ;;
	esac
	if [[ -n "$BROWSER" && "$1" = (http|https)://* ]]
	then
		"$BROWSER" "$@"
		return
	fi
	${=open_cmd} "$@" &> /dev/null
}
p10k () {
	[[ $# != 1 || $1 != finalize ]] || {
		p10k-instant-prompt-finalize
		return 0
	}
	eval "$__p9k_intro_no_reply"
	if (( !ARGC ))
	then
		print -rP -- $__p9k_p10k_usage >&2
		return 1
	fi
	case $1 in
		(segment) local REPLY
			local -a reply
			shift
			local -i OPTIND
			local OPTARG opt state bg=0 fg icon cond text ref=0 expand=0 
			while getopts ':s:b:f:i:c:t:reh' opt
			do
				case $opt in
					(s) state=$OPTARG  ;;
					(b) bg=$OPTARG  ;;
					(f) fg=$OPTARG  ;;
					(i) icon=$OPTARG  ;;
					(c) cond=${OPTARG:-'${:-}'}  ;;
					(t) text=$OPTARG  ;;
					(r) ref=1  ;;
					(e) expand=1  ;;
					(+r) ref=0  ;;
					(+e) expand=0  ;;
					(h) print -rP -- $__p9k_p10k_segment_usage
						return 0 ;;
					(?) print -rP -- $__p9k_p10k_segment_usage >&2
						return 1 ;;
				esac
			done
			if (( OPTIND <= ARGC ))
			then
				print -rP -- $__p9k_p10k_segment_usage >&2
				return 1
			fi
			if [[ -z $_p9k__prompt_side ]]
			then
				print -rP -- "%1F[ERROR]%f %Bp10k segment%b: can be called only during prompt rendering." >&2
				if (( !ARGC ))
				then
					print -rP -- ""
					print -rP -- "For help, type:" >&2
					print -rP -- ""
					print -rP -- "  %2Fp10k%f %Bhelp%b %Bsegment%b" >&2
				fi
				return 1
			fi
			(( ref )) || icon=$'\1'$icon 
			typeset -i _p9k__has_upglob
			"_p9k_${_p9k__prompt_side}_prompt_segment" "prompt_${_p9k__segment_name}${state:+_${${(U)state}//İ/I}}" "$bg" "${fg:-$_p9k_color1}" "$icon" "$expand" "$cond" "$text"
			return 0 ;;
		(display) if (( ARGC == 1 ))
			then
				print -rP -- $__p9k_p10k_display_usage >&2
				return 1
			fi
			shift
			local -i k dump
			local opt prev new pair list name var
			while getopts ':har' opt
			do
				case $opt in
					(r) if (( __p9k_reset_state > 0 ))
						then
							__p9k_reset_state=2 
						else
							__p9k_reset_state=-1 
						fi ;;
					(a) dump=1  ;;
					(h) print -rP -- $__p9k_p10k_display_usage
						return 0 ;;
					(?) print -rP -- $__p9k_p10k_display_usage >&2
						return 1 ;;
				esac
			done
			if (( dump ))
			then
				reply=() 
				shift $((OPTIND-1))
				(( ARGC )) || set -- '*'
				for opt
				do
					for k in ${(u@)_p9k_display_k[(I)$opt]:/(#m)*/$_p9k_display_k[$MATCH]}
					do
						reply+=($_p9k__display_v[k,k+1]) 
					done
				done
				if (( __p9k_reset_state == -1 ))
				then
					_p9k_reset_prompt
				fi
				return 0
			fi
			local REPLY
			local -a reply
			for opt in "${@:$OPTIND}"
			do
				pair=(${(s:=:)opt}) 
				list=(${(s:,:)${pair[2]}}) 
				if [[ ${(b)pair[1]} == $pair[1] ]]
				then
					local ks=($_p9k_display_k[$pair[1]]) 
				else
					local ks=(${(u@)_p9k_display_k[(I)$pair[1]]:/(#m)*/$_p9k_display_k[$MATCH]}) 
				fi
				for k in $ks
				do
					if (( $#list == 1 ))
					then
						[[ $_p9k__display_v[k+1] == $list[1] ]] && continue
						new=$list[1] 
					else
						new=${list[list[(I)$_p9k__display_v[k+1]]+1]:-$list[1]} 
						[[ $_p9k__display_v[k+1] == $new ]] && continue
					fi
					_p9k__display_v[k+1]=$new 
					name=$_p9k__display_v[k] 
					if [[ $name == (empty_line|ruler) ]]
					then
						var=_p9k__${name}_i 
						[[ $new == show ]] && unset $var || typeset -gi $var=3
					elif [[ $name == (#b)(<->)(*) ]]
					then
						var=_p9k__${match[1]}${${${${match[2]//\/}/#left/l}/#right/r}/#gap/g} 
						[[ $new == hide ]] && typeset -g $var= || unset $var
					fi
					if (( __p9k_reset_state > 0 ))
					then
						__p9k_reset_state=2 
					else
						__p9k_reset_state=-1 
					fi
				done
			done
			if (( __p9k_reset_state == -1 ))
			then
				_p9k_reset_prompt
			fi ;;
		(configure) if (( ARGC > 1 ))
			then
				print -rP -- $__p9k_p10k_configure_usage >&2
				return 1
			fi
			local REPLY
			local -a reply
			p9k_configure "$@" || return ;;
		(reload) if (( ARGC > 1 ))
			then
				print -rP -- $__p9k_p10k_reload_usage >&2
				return 1
			fi
			(( $+_p9k__force_must_init )) || return 0
			_p9k__force_must_init=1  ;;
		(help) local var=__p9k_p10k_$2_usage 
			if (( $+parameters[$var] ))
			then
				print -rP -- ${(P)var}
				return 0
			elif (( ARGC == 1 ))
			then
				print -rP -- $__p9k_p10k_usage
				return 0
			else
				print -rP -- $__p9k_p10k_usage >&2
				return 1
			fi ;;
		(finalize) print -rP -- $__p9k_p10k_finalize_usage >&2
			return 1 ;;
		(clear-instant-prompt) if (( $+__p9k_instant_prompt_active ))
			then
				_p9k_clear_instant_prompt
				unset __p9k_instant_prompt_active
			fi
			return 0 ;;
		(*) print -rP -- $__p9k_p10k_usage >&2
			return 1 ;;
	esac
}
p10k-instant-prompt-finalize () {
	unsetopt local_options
	(( ${+__p9k_instant_prompt_active} )) && unsetopt prompt_cr prompt_sp || setopt prompt_cr prompt_sp
}
p9k_configure () {
	eval "$__p9k_intro"
	_p9k_can_configure || return
	(
		set -- -f
		builtin source $__p9k_root_dir/internal/wizard.zsh
	)
	local ret=$? 
	case $ret in
		(0) builtin source $__p9k_cfg_path
			_p9k__force_must_init=1  ;;
		(69) return 0 ;;
		(*) return $ret ;;
	esac
}
p9k_prompt_segment () {
	p10k segment "$@"
}
parse_git_dirty () {
	local STATUS
	local -a FLAGS
	FLAGS=('--porcelain') 
	if [[ "$(__git_prompt_git config --get oh-my-zsh.hide-dirty)" != "1" ]]
	then
		if [[ "${DISABLE_UNTRACKED_FILES_DIRTY:-}" == "true" ]]
		then
			FLAGS+='--untracked-files=no' 
		fi
		case "${GIT_STATUS_IGNORE_SUBMODULES:-}" in
			(git)  ;;
			(*) FLAGS+="--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty}"  ;;
		esac
		STATUS=$(__git_prompt_git status ${FLAGS} 2> /dev/null | tail -n 1) 
	fi
	if [[ -n $STATUS ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
	else
		echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
	fi
}
powerlevel10k_plugin_unload () {
	prompt_powerlevel9k_teardown
}
print_icon () {
	eval "$__p9k_intro"
	_p9k_init_icons
	local var=POWERLEVEL9K_$1 
	if (( $+parameters[$var] ))
	then
		echo -n - ${(P)var}
	else
		echo -n - $icons[$1]
	fi
}
prompt__p9k_internal_nothing () {
	_p9k__prompt+='${_p9k__sss::=}' 
}
prompt_anaconda () {
	local msg
	if _p9k_python_version
	then
		P9K_ANACONDA_PYTHON_VERSION=$_p9k__ret 
		if (( _POWERLEVEL9K_ANACONDA_SHOW_PYTHON_VERSION ))
		then
			msg="${P9K_ANACONDA_PYTHON_VERSION//\%/%%} " 
		fi
	else
		unset P9K_ANACONDA_PYTHON_VERSION
	fi
	local p=${CONDA_PREFIX:-$CONDA_ENV_PATH} 
	msg+="$_POWERLEVEL9K_ANACONDA_LEFT_DELIMITER${${p:t}//\%/%%}$_POWERLEVEL9K_ANACONDA_RIGHT_DELIMITER" 
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '' "$msg"
}
prompt_asdf () {
	_p9k_asdf_check_meta || _p9k_asdf_init_meta || return
	local -A versions
	local -a stat
	local -i has_global
	local dirs=($_p9k__parent_dirs) 
	local mtimes=($_p9k__parent_mtimes) 
	if [[ $dirs[-1] != ~ ]]
	then
		zstat -A stat +mtime ~ 2> /dev/null || return
		dirs+=(~) 
		mtimes+=($stat[1]) 
	fi
	local elem
	for elem in ${(@)${:-{1..$#dirs}}/(#m)*/${${:-$MATCH:$_p9k__asdf_dir2files[$dirs[MATCH]]}#$MATCH:$mtimes[MATCH]:}}
	do
		if [[ $elem == *:* ]]
		then
			local dir=$dirs[${elem%%:*}] 
			zstat -A stat +mtime $dir 2> /dev/null || return
			local files=($dir/.tool-versions(N) $dir/${(k)^_p9k_asdf_file_info}(N)) 
			_p9k__asdf_dir2files[$dir]=$stat[1]:${(pj:\0:)files} 
		else
			local files=(${(0)elem}) 
		fi
		if [[ ${files[1]:h} == ~ ]]
		then
			has_global=1 
			local -A local_versions=(${(kv)versions}) 
			versions=() 
		fi
		local file
		for file in $files
		do
			[[ $file == */.tool-versions ]]
			_p9k_asdf_parse_version_file $file $? || return
		done
	done
	if (( ! has_global ))
	then
		has_global=1 
		local -A local_versions=(${(kv)versions}) 
		versions=() 
	fi
	if [[ -r $ASDF_DEFAULT_TOOL_VERSIONS_FILENAME ]]
	then
		_p9k_asdf_parse_version_file $ASDF_DEFAULT_TOOL_VERSIONS_FILENAME 0 || return
	fi
	local plugin
	for plugin in ${(k)_p9k_asdf_plugins}
	do
		local upper=${${(U)plugin//-/_}//İ/I} 
		if (( $+parameters[_POWERLEVEL9K_ASDF_${upper}_SOURCES] ))
		then
			local sources=(${(P)${:-_POWERLEVEL9K_ASDF_${upper}_SOURCES}}) 
		else
			local sources=($_POWERLEVEL9K_ASDF_SOURCES) 
		fi
		local version="${(P)${:-ASDF_${upper}_VERSION}}" 
		if [[ -n $version ]]
		then
			(( $sources[(I)shell] )) || continue
		else
			version=$local_versions[$plugin] 
			if [[ -n $version ]]
			then
				(( $sources[(I)local] )) || continue
			else
				version=$versions[$plugin] 
				[[ -n $version ]] || continue
				(( $sources[(I)global] )) || continue
			fi
		fi
		if [[ $version == $versions[$plugin] ]]
		then
			if (( $+parameters[_POWERLEVEL9K_ASDF_${upper}_PROMPT_ALWAYS_SHOW] ))
			then
				(( _POWERLEVEL9K_ASDF_${upper}_PROMPT_ALWAYS_SHOW )) || continue
			else
				(( _POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW )) || continue
			fi
		fi
		if [[ $version == system ]]
		then
			if (( $+parameters[_POWERLEVEL9K_ASDF_${upper}_SHOW_SYSTEM] ))
			then
				(( _POWERLEVEL9K_ASDF_${upper}_SHOW_SYSTEM )) || continue
			else
				(( _POWERLEVEL9K_ASDF_SHOW_SYSTEM )) || continue
			fi
		fi
		_p9k_get_icon $0_$upper ${upper}_ICON $plugin
		_p9k_prompt_segment $0_$upper green $_p9k_color1 $'\1'$_p9k__ret 0 '' ${version//\%/%%}
	done
}
prompt_aws () {
	typeset -g P9K_AWS_PROFILE="${AWS_SSO_PROFILE:-${AWS_VAULT:-${AWSUME_PROFILE:-${AWS_PROFILE:-$AWS_DEFAULT_PROFILE}}}}" 
	local pat class state
	for pat class in "${_POWERLEVEL9K_AWS_CLASSES[@]}"
	do
		if [[ $P9K_AWS_PROFILE == ${~pat} ]]
		then
			[[ -n $class ]] && state=_${${(U)class}//İ/I} 
			break
		fi
	done
	if [[ -n ${AWS_REGION:-$AWS_DEFAULT_REGION} ]]
	then
		typeset -g P9K_AWS_REGION=${AWS_REGION:-$AWS_DEFAULT_REGION} 
	else
		local cfg=${AWS_CONFIG_FILE:-~/.aws/config} 
		if ! _p9k_cache_stat_get $0 $cfg
		then
			local -a reply
			_p9k_parse_aws_config $cfg
			_p9k_cache_stat_set $reply
		fi
		local prefix=$#P9K_AWS_PROFILE:$P9K_AWS_PROFILE: 
		local kv=$_p9k__cache_val[(r)${(b)prefix}*] 
		typeset -g P9K_AWS_REGION=${kv#$prefix} 
	fi
	_p9k_prompt_segment "$0$state" red white 'AWS_ICON' 0 '' "${P9K_AWS_PROFILE//\%/%%}"
}
prompt_aws_eb_env () {
	_p9k_upglob .elasticbeanstalk -/ && return
	local dir=$_p9k__parent_dirs[$?] 
	if ! _p9k_cache_stat_get $0 $dir/.elasticbeanstalk/config.yml
	then
		local env
		env="$(command eb list 2>/dev/null)"  || env= 
		env="${${(@M)${(@f)env}:#\* *}#\* }" 
		_p9k_cache_stat_set "$env"
	fi
	[[ -n $_p9k__cache_val[1] ]] || return
	_p9k_prompt_segment "$0" black green 'AWS_EB_ICON' 0 '' "${_p9k__cache_val[1]//\%/%%}"
}
prompt_azure () {
	local name cfg=${AZURE_CONFIG_DIR:-$HOME/.azure}/azureProfile.json 
	if _p9k_cache_stat_get $0 $cfg
	then
		name=$_p9k__cache_val[1] 
	else
		if (( $+commands[jq] )) && name="$(jq -r '[.subscriptions[]|select(.isDefault==true)|.name][]|strings' $cfg 2>/dev/null)" 
		then
			name=${name%%$'\n'*} 
		elif ! name="$(az account show --query name --output tsv 2>/dev/null)" 
		then
			name= 
		fi
		_p9k_cache_stat_set "$name"
	fi
	[[ -n $name ]] || return
	local pat class state
	for pat class in "${_POWERLEVEL9K_AZURE_CLASSES[@]}"
	do
		if [[ $name == ${~pat} ]]
		then
			[[ -n $class ]] && state=_${${(U)class}//İ/I} 
			break
		fi
	done
	_p9k_prompt_segment "$0$state" "blue" "white" "AZURE_ICON" 0 '' "${name//\%/%%}"
}
prompt_background_jobs () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	local msg
	if (( _POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE ))
	then
		if (( _POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE_ALWAYS ))
		then
			msg='${(%):-%j}' 
		else
			msg='${${(%):-%j}:#1}' 
		fi
	fi
	_p9k_prompt_segment $0 "$_p9k_color1" cyan BACKGROUND_JOBS_ICON 1 '${${(%):-%j}:#0}' "$msg"
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_battery () {
	[[ $_p9k_os == (Linux|Android) ]] && _p9k_prompt_battery_set_args
	(( $#_p9k__battery_args )) && _p9k_prompt_segment "${_p9k__battery_args[@]}"
}
prompt_chezmoi_shell () {
	_p9k_prompt_segment $0 blue $_p9k_color1 CHEZMOI_ICON 0 '' ''
}
prompt_chruby () {
	local v=${(M)RUBY_ENGINE:#$~_POWERLEVEL9K_CHRUBY_SHOW_ENGINE_PATTERN} 
	[[ $_POWERLEVEL9K_CHRUBY_SHOW_VERSION == 1 && -n $RUBY_VERSION ]] && v+=${v:+ }$RUBY_VERSION 
	_p9k_prompt_segment "$0" "red" "$_p9k_color1" 'RUBY_ICON' 0 '' "${v//\%/%%}"
}
prompt_command_execution_time () {
	(( $+P9K_COMMAND_DURATION_SECONDS )) || return
	(( P9K_COMMAND_DURATION_SECONDS >= _POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD )) || return
	if (( P9K_COMMAND_DURATION_SECONDS < 60 ))
	then
		if (( !_POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION ))
		then
			local -i sec=$((P9K_COMMAND_DURATION_SECONDS + 0.5)) 
		else
			local -F $_POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION sec=P9K_COMMAND_DURATION_SECONDS 
		fi
		local text=${sec}s 
	else
		local -i d=$((P9K_COMMAND_DURATION_SECONDS + 0.5)) 
		if [[ $_POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT == "H:M:S" ]]
		then
			local text=${(l.2..0.)$((d % 60))} 
			if (( d >= 60 ))
			then
				text=${(l.2..0.)$((d / 60 % 60))}:$text 
				if (( d >= 36000 ))
				then
					text=$((d / 3600)):$text 
				elif (( d >= 3600 ))
				then
					text=0$((d / 3600)):$text 
				fi
			fi
		else
			local text="$((d % 60))s" 
			if (( d >= 60 ))
			then
				text="$((d / 60 % 60))m $text" 
				if (( d >= 3600 ))
				then
					text="$((d / 3600 % 24))h $text" 
					if (( d >= 86400 ))
					then
						text="$((d / 86400))d $text" 
					fi
				fi
			fi
		fi
	fi
	_p9k_prompt_segment "$0" "red" "yellow1" 'EXECUTION_TIME_ICON' 0 '' $text
}
prompt_context () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	local content
	if [[ $_POWERLEVEL9K_ALWAYS_SHOW_CONTEXT == 0 && -n $DEFAULT_USER && $P9K_SSH == 0 ]]
	then
		local user="${(%):-%n}" 
		if [[ $user == $DEFAULT_USER ]]
		then
			content="${user//\%/%%}" 
		fi
	fi
	local state
	if (( P9K_SSH ))
	then
		if [[ -n "$SUDO_COMMAND" ]]
		then
			state="REMOTE_SUDO" 
		else
			state="REMOTE" 
		fi
	elif [[ -n "$SUDO_COMMAND" ]]
	then
		state="SUDO" 
	else
		state="DEFAULT" 
	fi
	local cond
	for state cond in $state '${${(%):-%#}:#\#}' ROOT '${${(%):-%#}:#\%}'
	do
		local text=$content 
		if [[ -z $text ]]
		then
			local var=_POWERLEVEL9K_CONTEXT_${state}_TEMPLATE 
			if (( $+parameters[$var] ))
			then
				text=${(P)var} 
				text=${(g::)text} 
			else
				text=$_POWERLEVEL9K_CONTEXT_TEMPLATE 
			fi
		fi
		_p9k_prompt_segment "$0_$state" "$_p9k_color1" yellow '' 0 "$cond" "$text"
	done
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_cpu_arch () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	local state text
	if _p9k_cache_ephemeral_get $0
	then
		state=$_p9k__cache_val[1] 
		text=$_p9k__cache_val[2] 
	else
		if [[ -r /proc/sys/kernel/arch ]]
		then
			text=$(</proc/sys/kernel/arch) 
		else
			local cmd
			for cmd in machine arch
			do
				(( $+commands[$cmd] )) || continue
				if text=$(command -- $cmd)  2> /dev/null && [[ $text == [a-zA-Z][a-zA-Z0-9_]# ]]
				then
					break
				else
					text= 
				fi
			done
		fi
		state=_${${(U)text}//İ/I} 
		_p9k_cache_ephemeral_set "$state" "$text"
	fi
	if [[ -n $text ]]
	then
		_p9k_prompt_segment "$0$state" "yellow" "$_p9k_color1" 'ARCH_ICON' 0 '' "$text"
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_date () {
	if [[ $_p9k__refresh_reason == precmd ]]
	then
		if [[ $+__p9k_instant_prompt_active == 1 && $__p9k_instant_prompt_date_format == $_POWERLEVEL9K_DATE_FORMAT ]]
		then
			_p9k__date=${__p9k_instant_prompt_date//\%/%%} 
		else
			_p9k__date=${${(%)_POWERLEVEL9K_DATE_FORMAT}//\%/%%} 
		fi
	fi
	_p9k_prompt_segment "$0" "$_p9k_color2" "$_p9k_color1" "DATE_ICON" 0 '' "$_p9k__date"
}
prompt_detect_virt () {
	local virt="$(systemd-detect-virt 2>/dev/null)" 
	if [[ "$virt" == "none" ]]
	then
		local -a inode
		if zstat -A inode +inode / 2> /dev/null && [[ $inode[1] != 2 ]]
		then
			virt="chroot" 
		fi
	fi
	if [[ -n "${virt}" ]]
	then
		_p9k_prompt_segment "$0" "$_p9k_color1" "yellow" '' 0 '' "${virt//\%/%%}"
	fi
}
prompt_dir () {
	if (( _POWERLEVEL9K_DIR_PATH_ABSOLUTE ))
	then
		local p=${(V)_p9k__cwd} 
		local -a parts=("${(s:/:)p}") 
	elif [[ -o auto_name_dirs ]]
	then
		local p=${(V)${_p9k__cwd/#(#b)$HOME(|\/*)/'~'$match[1]}} 
		local -a parts=("${(s:/:)p}") 
	else
		local p=${(%):-%~} 
		if [[ $p == '~['* ]]
		then
			local func='' 
			local -a parts=() 
			for func in zsh_directory_name $zsh_directory_name_functions
			do
				local reply=() 
				if (( $+functions[$func] )) && $func d $_p9k__cwd && [[ $p == '~['${(V)reply[1]}']'* ]]
				then
					parts+='~['${(V)reply[1]}']' 
					break
				fi
			done
			if (( $#parts ))
			then
				parts+=(${(s:/:)${p#$parts[1]}}) 
			else
				p=${(V)_p9k__cwd} 
				parts=("${(s:/:)p}") 
			fi
		else
			local -a parts=("${(s:/:)p}") 
		fi
	fi
	local -i fake_first=0 expand=0 shortenlen=${_POWERLEVEL9K_SHORTEN_DIR_LENGTH:--1} 
	if (( $+_POWERLEVEL9K_SHORTEN_DELIMITER ))
	then
		local delim=$_POWERLEVEL9K_SHORTEN_DELIMITER 
	else
		if [[ $langinfo[CODESET] == (utf|UTF)(-|)8 ]]
		then
			local delim=$'\u2026' 
		else
			local delim='..' 
		fi
	fi
	case $_POWERLEVEL9K_SHORTEN_STRATEGY in
		(truncate_absolute | truncate_absolute_chars) if (( shortenlen > 0 && $#p > shortenlen ))
			then
				_p9k_shorten_delim_len $delim
				if (( $#p > shortenlen + $_p9k__ret ))
				then
					local -i n=shortenlen 
					local -i i=$#parts 
					while true
					do
						local dir=$parts[i] 
						local -i len=$(( $#dir + (i > 1) )) 
						if (( len <= n ))
						then
							(( n -= len ))
							(( --i ))
						else
							parts[i]=$'\1'$dir[-n,-1] 
							parts[1,i-1]=() 
							break
						fi
					done
				fi
			fi ;;
		(truncate_with_package_name | truncate_middle | truncate_from_right) () {
				[[ $_POWERLEVEL9K_SHORTEN_STRATEGY == truncate_with_package_name && $+commands[jq] == 1 && $#_POWERLEVEL9K_DIR_PACKAGE_FILES > 0 ]] || return
				local pats="(${(j:|:)_POWERLEVEL9K_DIR_PACKAGE_FILES})" 
				local -i i=$#parts 
				local dir=$_p9k__cwd 
				for ((; i > 0; --i )) do
					local markers=($dir/${~pats}(N)) 
					if (( $#markers ))
					then
						local pat= pkg_file= 
						for pat in $_POWERLEVEL9K_DIR_PACKAGE_FILES
						do
							for pkg_file in $markers
							do
								[[ $pkg_file == $dir/${~pat} ]] || continue
								if ! _p9k_cache_stat_get $0_pkg $pkg_file
								then
									local pkg_name='' 
									pkg_name="$(jq -j '.name | select(. != null)' <$pkg_file 2>/dev/null)"  || pkg_name='' 
									_p9k_cache_stat_set "$pkg_name"
								fi
								[[ -n $_p9k__cache_val[1] ]] || continue
								parts[1,i]=($_p9k__cache_val[1]) 
								fake_first=1 
								return 0
							done
						done
					fi
					dir=${dir:h} 
				done
			}
			if (( shortenlen > 0 ))
			then
				_p9k_shorten_delim_len $delim
				local -i d=_p9k__ret pref=shortenlen suf=0 i=2 
				[[ $_POWERLEVEL9K_SHORTEN_STRATEGY == truncate_middle ]] && suf=pref 
				for ((; i < $#parts; ++i )) do
					local dir=$parts[i] 
					if (( $#dir > pref + suf + d ))
					then
						dir[pref+1,-suf-1]=$'\1' 
						parts[i]=$dir 
					fi
				done
			fi ;;
		(truncate_to_last) shortenlen=${_POWERLEVEL9K_SHORTEN_DIR_LENGTH:-1} 
			(( shortenlen > 0 )) || shortenlen=1 
			local -i i='shortenlen+1' 
			if [[ $#parts -gt i || ( $p[1] != / && $#parts -gt shortenlen ) ]]
			then
				fake_first=1 
				parts[1,-i]=() 
			fi ;;
		(truncate_to_first_and_last) if (( shortenlen > 0 ))
			then
				local -i i=$(( shortenlen + 1 )) 
				[[ $p == /* ]] && (( ++i ))
				for ((; i <= $#parts - shortenlen; ++i )) do
					parts[i]=$'\1' 
				done
			fi ;;
		(truncate_to_unique) expand=1 
			delim=${_POWERLEVEL9K_SHORTEN_DELIMITER-'*'} 
			shortenlen=${_POWERLEVEL9K_SHORTEN_DIR_LENGTH:-1} 
			(( shortenlen >= 0 )) || shortenlen=1 
			local rp=${(g:oce:)p} 
			local rparts=("${(@s:/:)rp}") 
			local -i i=2 e=$(($#parts - shortenlen)) 
			if [[ -n $_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER ]]
			then
				(( e += shortenlen ))
				local orig=("$parts[2]" "${(@)parts[$((shortenlen > $#parts ? -$#parts : -shortenlen)),-1]}") 
			elif [[ $p[1] == / ]]
			then
				(( ++i ))
			fi
			if (( i <= e ))
			then
				local mtimes=(${(Oa)_p9k__parent_mtimes:$(($#parts-e)):$((e-i+1))}) 
				local key="${(pj.:.)mtimes}" 
			else
				local key= 
			fi
			if ! _p9k_cache_ephemeral_get $0 $e $i $_p9k__cwd $p || [[ $key != $_p9k__cache_val[1] ]]
			then
				local rtail=${(j./.)rparts[i,-1]} 
				local parent=$_p9k__cwd[1,-2-$#rtail] 
				_p9k_prompt_length $delim
				local -i real_delim_len=_p9k__ret 
				[[ -n $parts[i-1] ]] && parts[i-1]="\${(Q)\${:-${(qqq)${(q)parts[i-1]}}}}"$'\2' 
				local -i d=${_POWERLEVEL9K_SHORTEN_DELIMITER_LENGTH:--1} 
				(( d >= 0 )) || d=real_delim_len 
				local -i m=1 
				for ((; i <= e; ++i, ++m )) do
					local sub=$parts[i] 
					local rsub=$rparts[i] 
					local dir=$parent/$rsub mtime=$mtimes[m] 
					local pair=$_p9k__dir_stat_cache[$dir] 
					if [[ $pair == ${mtime:-x}:* ]]
					then
						parts[i]=${pair#*:} 
					else
						[[ $sub != *["~!#\`\$^&*()\\\"'<>?{}[]"]* ]]
						local -i q=$? 
						if [[ -n $_POWERLEVEL9K_SHORTEN_FOLDER_MARKER && -n $dir/${~_POWERLEVEL9K_SHORTEN_FOLDER_MARKER}(#qN) ]]
						then
							(( q )) && parts[i]="\${(Q)\${:-${(qqq)${(q)sub}}}}" 
							parts[i]+=$'\2' 
						else
							local -i j=$rsub[(i)[^.]] 
							for ((; j + d < $#rsub; ++j )) do
								local -a matching=($parent/$rsub[1,j]*/(N)) 
								(( $#matching == 1 )) && break
							done
							local -i saved=$((${(m)#${(V)${rsub:$j}}} - d)) 
							if (( saved > 0 ))
							then
								if (( q ))
								then
									parts[i]='${${${_p9k__d:#-*}:+${(Q)${:-'${(qqq)${(q)sub}}'}}}:-${(Q)${:-' 
									parts[i]+=$'\3'${(qqq)${(q)${(V)${rsub[1,j]}}}}$'}}\1\3''${$((_p9k__d+='$saved'))+}}' 
								else
									parts[i]='${${${_p9k__d:#-*}:+'$sub$'}:-\3'${(V)${rsub[1,j]}}$'\1\3''${$((_p9k__d+='$saved'))+}}' 
								fi
							else
								(( q )) && parts[i]="\${(Q)\${:-${(qqq)${(q)sub}}}}" 
							fi
						fi
						[[ -n $mtime ]] && _p9k__dir_stat_cache[$dir]="$mtime:$parts[i]" 
					fi
					parent+=/$rsub 
				done
				if [[ -n $_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER ]]
				then
					local _2=$'\2' 
					if [[ $_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER == last* ]]
					then
						(( e = ${parts[(I)*$_2]} + ${_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER#*:} ))
					else
						(( e = ${parts[(ib:2:)*$_2]} + ${_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER#*:} ))
					fi
					if (( e > 1 && e <= $#parts ))
					then
						parts[1,e-1]=() 
						fake_first=1 
					elif [[ $p == /?* ]]
					then
						parts[2]="\${(Q)\${:-${(qqq)${(q)orig[1]}}}}"$'\2' 
					fi
					for ((i = $#parts < shortenlen ? $#parts : shortenlen; i > 0; --i)) do
						[[ $#parts[-i] == *$'\2' ]] && continue
						if [[ $orig[-i] == *["~!#\`\$^&*()\\\"'<>?{}[]"]* ]]
						then
							parts[-i]='${(Q)${:-'${(qqq)${(q)orig[-i]}}'}}'$'\2' 
						else
							parts[-i]=${orig[-i]}$'\2' 
						fi
					done
				else
					for ((; i <= $#parts; ++i)) do
						[[ $parts[i] == *["~!#\`\$^&*()\\\"'<>?{}[]"]* ]] && parts[i]='${(Q)${:-'${(qqq)${(q)parts[i]}}'}}' 
						parts[i]+=$'\2' 
					done
				fi
				_p9k_cache_ephemeral_set "$key" "${parts[@]}"
			fi
			parts=("${(@)_p9k__cache_val[2,-1]}")  ;;
		(truncate_with_folder_marker) if [[ -n $_POWERLEVEL9K_SHORTEN_FOLDER_MARKER ]]
			then
				local dir=$_p9k__cwd 
				local -a m=() 
				local -i i=$(($#parts - 1)) 
				for ((; i > 1; --i )) do
					dir=${dir:h} 
					[[ -n $dir/${~_POWERLEVEL9K_SHORTEN_FOLDER_MARKER}(#qN) ]] && m+=$i 
				done
				m+=1 
				for ((i=1; i < $#m; ++i )) do
					(( m[i] - m[i+1] > 2 )) && parts[m[i+1]+1,m[i]-1]=($'\1') 
				done
			fi ;;
		(*) if (( shortenlen > 0 ))
			then
				local -i len=$#parts 
				[[ -z $parts[1] ]] && (( --len ))
				if (( len > shortenlen ))
				then
					parts[1,-shortenlen-1]=($'\1') 
				fi
			fi ;;
	esac
	(( !_POWERLEVEL9K_DIR_SHOW_WRITABLE )) || [[ -w $_p9k__cwd ]]
	local -i w=$? 
	(( w && _POWERLEVEL9K_DIR_SHOW_WRITABLE > 2 )) && [[ ! -e $_p9k__cwd ]] && w=2 
	if ! _p9k_cache_ephemeral_get $0 $_p9k__cwd $p $w $fake_first "${parts[@]}"
	then
		local state=$0 
		local icon='' 
		local a='' b='' c='' 
		for a b c in "${_POWERLEVEL9K_DIR_CLASSES[@]}"
		do
			if [[ $_p9k__cwd == ${~a} ]]
			then
				[[ -n $b ]] && state+=_${${(U)b}//İ/I} 
				icon=$'\1'$c 
				break
			fi
		done
		if (( w ))
		then
			if (( _POWERLEVEL9K_DIR_SHOW_WRITABLE == 1 ))
			then
				state=${0}_NOT_WRITABLE 
			elif (( w == 2 ))
			then
				state+=_NON_EXISTENT 
			else
				state+=_NOT_WRITABLE 
			fi
			icon=LOCK_ICON 
		fi
		local state_u=${${(U)state}//İ/I} 
		local style=%b 
		_p9k_color $state BACKGROUND blue
		_p9k_background $_p9k__ret
		style+=$_p9k__ret 
		_p9k_color $state FOREGROUND "$_p9k_color1"
		_p9k_foreground $_p9k__ret
		style+=$_p9k__ret 
		if (( expand ))
		then
			_p9k_escape_style $style
			style=$_p9k__ret 
		fi
		parts=("${(@)parts//\%/%%}") 
		if [[ $_POWERLEVEL9K_HOME_FOLDER_ABBREVIATION != '~' && $fake_first == 0 && $p == ('~'|'~/'*) ]]
		then
			(( expand )) && _p9k_escape $_POWERLEVEL9K_HOME_FOLDER_ABBREVIATION || _p9k__ret=$_POWERLEVEL9K_HOME_FOLDER_ABBREVIATION 
			parts[1]=$_p9k__ret 
			[[ $_p9k__ret == *%* ]] && parts[1]+=$style 
		elif [[ $_POWERLEVEL9K_DIR_OMIT_FIRST_CHARACTER == 1 && $fake_first == 0 && $#parts > 1 && -z $parts[1] && -n $parts[2] ]]
		then
			parts[1]=() 
		fi
		local last_style= 
		_p9k_param $state PATH_HIGHLIGHT_BOLD ''
		[[ $_p9k__ret == true ]] && last_style+=%B 
		if (( $+parameters[_POWERLEVEL9K_DIR_PATH_HIGHLIGHT_FOREGROUND] ||
          $+parameters[_POWERLEVEL9K_${state_u}_PATH_HIGHLIGHT_FOREGROUND] ))
		then
			_p9k_color $state PATH_HIGHLIGHT_FOREGROUND ''
			_p9k_foreground $_p9k__ret
			last_style+=$_p9k__ret 
		fi
		if [[ -n $last_style ]]
		then
			(( expand )) && _p9k_escape_style $last_style || _p9k__ret=$last_style 
			parts[-1]=$_p9k__ret${parts[-1]//$'\1'/$'\1'$_p9k__ret}$style 
		fi
		local anchor_style= 
		_p9k_param $state ANCHOR_BOLD ''
		[[ $_p9k__ret == true ]] && anchor_style+=%B 
		if (( $+parameters[_POWERLEVEL9K_DIR_ANCHOR_FOREGROUND] ||
          $+parameters[_POWERLEVEL9K_${state_u}_ANCHOR_FOREGROUND] ))
		then
			_p9k_color $state ANCHOR_FOREGROUND ''
			_p9k_foreground $_p9k__ret
			anchor_style+=$_p9k__ret 
		fi
		if [[ -n $anchor_style ]]
		then
			(( expand )) && _p9k_escape_style $anchor_style || _p9k__ret=$anchor_style 
			if [[ -z $last_style ]]
			then
				parts=("${(@)parts/%(#b)(*)$'\2'/$_p9k__ret$match[1]$style}") 
			else
				(( $#parts > 1 )) && parts[1,-2]=("${(@)parts[1,-2]/%(#b)(*)$'\2'/$_p9k__ret$match[1]$style}") 
				parts[-1]=${parts[-1]/$'\2'} 
			fi
		else
			parts=("${(@)parts/$'\2'}") 
		fi
		if (( $+parameters[_POWERLEVEL9K_DIR_SHORTENED_FOREGROUND] ||
          $+parameters[_POWERLEVEL9K_${state_u}_SHORTENED_FOREGROUND] ))
		then
			_p9k_color $state SHORTENED_FOREGROUND ''
			_p9k_foreground $_p9k__ret
			(( expand )) && _p9k_escape_style $_p9k__ret
			local shortened_fg=$_p9k__ret 
			(( expand )) && _p9k_escape $delim || _p9k__ret=$delim 
			[[ $_p9k__ret == *%* ]] && _p9k__ret+=$style$shortened_fg 
			parts=("${(@)parts/(#b)$'\3'(*)$'\1'(*)$'\3'/$shortened_fg$match[1]$_p9k__ret$match[2]$style}") 
			parts=("${(@)parts/(#b)(*)$'\1'(*)/$shortened_fg$match[1]$_p9k__ret$match[2]$style}") 
		else
			(( expand )) && _p9k_escape $delim || _p9k__ret=$delim 
			[[ $_p9k__ret == *%* ]] && _p9k__ret+=$style 
			parts=("${(@)parts/$'\1'/$_p9k__ret}") 
			parts=("${(@)parts//$'\3'}") 
		fi
		if [[ $_p9k__cwd == / && $_POWERLEVEL9K_DIR_OMIT_FIRST_CHARACTER == 1 ]]
		then
			local sep='/' 
		else
			local sep='' 
			if (( $+parameters[_POWERLEVEL9K_DIR_PATH_SEPARATOR_FOREGROUND] ||
            $+parameters[_POWERLEVEL9K_${state_u}_PATH_SEPARATOR_FOREGROUND] ))
			then
				_p9k_color $state PATH_SEPARATOR_FOREGROUND ''
				_p9k_foreground $_p9k__ret
				(( expand )) && _p9k_escape_style $_p9k__ret
				sep=$_p9k__ret 
			fi
			_p9k_param $state PATH_SEPARATOR /
			_p9k__ret=${(g::)_p9k__ret} 
			(( expand )) && _p9k_escape $_p9k__ret
			sep+=$_p9k__ret 
			[[ $sep == *%* ]] && sep+=$style 
		fi
		local content="${(pj.$sep.)parts}" 
		if (( _POWERLEVEL9K_DIR_HYPERLINK && _p9k_term_has_href )) && [[ $_p9k__cwd == /* ]]
		then
			_p9k_url_escape $_p9k__cwd
			local header=$'%{\e]8;;file://'$_p9k__ret$'\a%}' 
			local footer=$'%{\e]8;;\a%}' 
			if (( expand ))
			then
				_p9k_escape $header
				header=$_p9k__ret 
				_p9k_escape $footer
				footer=$_p9k__ret 
			fi
			content=$header$content$footer 
		fi
		(( expand )) && _p9k_prompt_length "${(e):-"\${\${_p9k__d::=0}+}$content"}" || _p9k__ret= 
		_p9k_cache_ephemeral_set "$state" "$icon" "$expand" "$content" $_p9k__ret
	fi
	if (( _p9k__cache_val[3] ))
	then
		if (( $+_p9k__dir ))
		then
			_p9k__cache_val[4]='${${_p9k__d::=-1024}+}'$_p9k__cache_val[4] 
		else
			_p9k__dir=$_p9k__cache_val[4] 
			_p9k__dir_len=$_p9k__cache_val[5] 
			_p9k__cache_val[4]='%{d%}'$_p9k__cache_val[4]'%{d%}' 
		fi
	fi
	_p9k_prompt_segment "$_p9k__cache_val[1]" "blue" "$_p9k_color1" "$_p9k__cache_val[2]" "$_p9k__cache_val[3]" "" "$_p9k__cache_val[4]"
}
prompt_dir_writable () {
	if [[ ! -w "$_p9k__cwd_a" ]]
	then
		_p9k_prompt_segment "$0_FORBIDDEN" "red" "yellow1" 'LOCK_ICON' 0 '' ''
	fi
}
prompt_direnv () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 $_p9k_color1 yellow DIRENV_ICON 0 '${DIRENV_DIR-}' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_disk_usage () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0_CRITICAL red white DISK_ICON 1 '$_p9k__disk_usage_critical' '$_p9k__disk_usage_pct%%'
	_p9k_prompt_segment $0_WARNING yellow $_p9k_color1 DISK_ICON 1 '$_p9k__disk_usage_warning' '$_p9k__disk_usage_pct%%'
	if (( ! _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING ))
	then
		_p9k_prompt_segment $0_NORMAL $_p9k_color1 yellow DISK_ICON 1 '$_p9k__disk_usage_normal' '$_p9k__disk_usage_pct%%'
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_docker_machine () {
	_p9k_prompt_segment "$0" "magenta" "$_p9k_color1" 'SERVER_ICON' 0 '' "${DOCKER_MACHINE_NAME//\%/%%}"
}
prompt_dotnet_version () {
	if (( _POWERLEVEL9K_DOTNET_VERSION_PROJECT_ONLY ))
	then
		_p9k_upglob 'project.json|global.json|packet.dependencies|*.csproj|*.fsproj|*.xproj|*.sln' -. && return
	fi
	local cfg
	_p9k_upglob global.json -. || cfg=$_p9k__parent_dirs[$?]/global.json 
	_p9k_cached_cmd 0 "$cfg" dotnet --version || return
	_p9k_prompt_segment "$0" "magenta" "white" 'DOTNET_ICON' 0 '' "$_p9k__ret"
}
prompt_dropbox () {
	local dropbox_status="$(dropbox-cli filestatus . | cut -d\  -f2-)" 
	if [[ "$dropbox_status" != 'unwatched' && "$dropbox_status" != "isn't running!" ]]
	then
		if [[ "$dropbox_status" =~ 'up to date' ]]
		then
			dropbox_status="" 
		fi
		_p9k_prompt_segment "$0" "white" "blue" "DROPBOX_ICON" 0 '' "${dropbox_status//\%/%%}"
	fi
}
prompt_fvm () {
	_p9k_fvm_new || _p9k_fvm_old
}
prompt_gcloud () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0_PARTIAL blue white GCLOUD_ICON 1 '${${(M)${#P9K_GCLOUD_PROJECT_NAME}:#0}:+$P9K_GCLOUD_ACCOUNT$P9K_GCLOUD_PROJECT_ID}' '${P9K_GCLOUD_ACCOUNT//\%/%%}:${P9K_GCLOUD_PROJECT_ID//\%/%%}'
	_p9k_prompt_segment $0_COMPLETE blue white GCLOUD_ICON 1 '$P9K_GCLOUD_PROJECT_NAME' '${P9K_GCLOUD_ACCOUNT//\%/%%}:${P9K_GCLOUD_PROJECT_ID//\%/%%}'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_go_version () {
	_p9k_cached_cmd 0 '' go version || return
	[[ $_p9k__ret == (#b)*go([[:digit:].]##)* ]] || return
	local v=$match[1] 
	if (( _POWERLEVEL9K_GO_VERSION_PROJECT_ONLY ))
	then
		local p=$GOPATH 
		if [[ -z $p ]]
		then
			if [[ -d $HOME/go ]]
			then
				p=$HOME/go 
			else
				p="$(go env GOPATH 2>/dev/null)"  && [[ -n $p ]] || return
			fi
		fi
		if [[ $_p9k__cwd/ != $p/* && $_p9k__cwd_a/ != $p/* ]]
		then
			_p9k_upglob go.mod -. && return
		fi
	fi
	_p9k_prompt_segment "$0" "green" "grey93" "GO_ICON" 0 '' "${v//\%/%%}"
}
prompt_goenv () {
	local v=${(j.:.)${(@)${(s.:.)GOENV_VERSION}#go-}} 
	if [[ -n $v ]]
	then
		(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)shell]} )) || return
	else
		(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $GOENV_DIR != (|.) ]]
		then
			[[ $GOENV_DIR == /* ]] && local dir=$GOENV_DIR  || local dir="$_p9k__cwd_a/$GOENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_pyenv_like_version_file $dir/.go-version go-
					then
						(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .go-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_pyenv_like_version_file $_p9k__parent_dirs[idx]/.go-version go-
			then
				(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)global]} )) || return
			_p9k_goenv_global_version
		fi
		v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_goenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_GOENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'GO_ICON' 0 '' "${v//\%/%%}"
}
prompt_google_app_cred () {
	unset P9K_GOOGLE_APP_CRED_{TYPE,PROJECT_ID,CLIENT_EMAIL}
	if ! _p9k_cache_stat_get $0 $GOOGLE_APPLICATION_CREDENTIALS
	then
		local -a lines
		local q='[.type//"", .project_id//"", .client_email//"", 0][]' 
		if lines=("${(@f)$(jq -r $q <$GOOGLE_APPLICATION_CREDENTIALS 2>/dev/null)}")  && (( $#lines == 4 ))
		then
			local text="${(j.:.)lines[1,-2]}" 
			local pat class state
			for pat class in "${_POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES[@]}"
			do
				if [[ $text == ${~pat} ]]
				then
					[[ -n $class ]] && state=_${${(U)class}//İ/I} 
					break
				fi
			done
			_p9k_cache_stat_set 1 "${(@)lines[1,-2]}" "$text" "$state"
		else
			_p9k_cache_stat_set 0
		fi
	fi
	(( _p9k__cache_val[1] )) || return
	P9K_GOOGLE_APP_CRED_TYPE=$_p9k__cache_val[2] 
	P9K_GOOGLE_APP_CRED_PROJECT_ID=$_p9k__cache_val[3] 
	P9K_GOOGLE_APP_CRED_CLIENT_EMAIL=$_p9k__cache_val[4] 
	_p9k_prompt_segment "$0$_p9k__cache_val[6]" "blue" "white" "GCLOUD_ICON" 0 '' "$_p9k__cache_val[5]"
}
prompt_haskell_stack () {
	if [[ -n $STACK_YAML ]]
	then
		(( ${_POWERLEVEL9K_HASKELL_STACK_SOURCES[(I)shell]} )) || return
		_p9k_haskell_stack_version $STACK_YAML
	else
		(( ${_POWERLEVEL9K_HASKELL_STACK_SOURCES[(I)local|global]} )) || return
		if _p9k_upglob stack.yaml -.
		then
			(( _POWERLEVEL9K_HASKELL_STACK_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_HASKELL_STACK_SOURCES[(I)global]} )) || return
			_p9k_haskell_stack_version ${STACK_ROOT:-~/.stack}/global-project/stack.yaml
		else
			local -i idx=$? 
			(( ${_POWERLEVEL9K_HASKELL_STACK_SOURCES[(I)local]} )) || return
			_p9k_haskell_stack_version $_p9k__parent_dirs[idx]/stack.yaml
		fi
	fi
	[[ -n $_p9k__ret ]] || return
	local v=$_p9k__ret 
	if (( !_POWERLEVEL9K_HASKELL_STACK_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_haskell_stack_version ${STACK_ROOT:-~/.stack}/global-project/stack.yaml
		[[ $v == $_p9k__ret ]] && return
	fi
	_p9k_prompt_segment "$0" "yellow" "$_p9k_color1" 'HASKELL_ICON' 0 '' "${v//\%/%%}"
}
prompt_history () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "grey50" "$_p9k_color1" '' 0 '' '%h'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_host () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	if (( P9K_SSH ))
	then
		_p9k_prompt_segment "$0_REMOTE" "${_p9k_color1}" yellow SSH_ICON 0 '' "$_POWERLEVEL9K_HOST_TEMPLATE"
	else
		_p9k_prompt_segment "$0_LOCAL" "${_p9k_color1}" yellow HOST_ICON 0 '' "$_POWERLEVEL9K_HOST_TEMPLATE"
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_ip () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "cyan" "$_p9k_color1" 'NETWORK_ICON' 1 '$P9K_IP_IP' '$P9K_IP_IP'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_java_version () {
	if (( _POWERLEVEL9K_JAVA_VERSION_PROJECT_ONLY ))
	then
		_p9k_upglob 'pom.xml|build.gradle.kts|build.sbt|deps.edn|project.clj|build.boot|*.(java|class|jar|gradle|clj|cljc)' -. && return
	fi
	local java=$commands[java] 
	if ! _p9k_cache_stat_get $0 $java ${JAVA_HOME:+$JAVA_HOME/release}
	then
		local v
		v="$(java -fullversion 2>&1)"  || v= 
		v=${${v#*\"}%\"*} 
		(( _POWERLEVEL9K_JAVA_VERSION_FULL )) || v=${v%%-*} 
		_p9k_cache_stat_set "${v//\%/%%}"
	fi
	[[ -n $_p9k__cache_val[1] ]] || return
	_p9k_prompt_segment "$0" "red" "white" "JAVA_ICON" 0 '' $_p9k__cache_val[1]
}
prompt_jenv () {
	if [[ -n $JENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_JENV_SOURCES[(I)shell]} )) || return
		local v=$JENV_VERSION 
	else
		(( ${_POWERLEVEL9K_JENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $JENV_DIR != (|.) ]]
		then
			[[ $JENV_DIR == /* ]] && local dir=$JENV_DIR  || local dir="$_p9k__cwd_a/$JENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.java-version
					then
						(( ${_POWERLEVEL9K_JENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .java-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.java-version
			then
				(( ${_POWERLEVEL9K_JENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_JENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_JENV_SOURCES[(I)global]} )) || return
			_p9k_jenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_JENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_jenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_JENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" white red 'JAVA_ICON' 0 '' "${v//\%/%%}"
}
prompt_kubecontext () {
	if ! _p9k_cache_stat_get $0 ${(s.:.)${KUBECONFIG:-$HOME/.kube/config}}
	then
		local name namespace cluster user cloud_name cloud_account cloud_zone cloud_cluster text state
		() {
			local cfg && cfg=(${(f)"$(kubectl config view -o=yaml 2>/dev/null)"})  || return
			local qstr='"*"' 
			local str='([^"'\''|>]*|'$qstr')' 
			local ctx=(${(@M)cfg:#current-context: $~str}) 
			(( $#ctx == 1 )) || return
			name=${ctx[1]#current-context: } 
			local -i pos=${cfg[(i)contexts:]} 
			{
				(( pos <= $#cfg )) || return
				shift $pos cfg
				pos=${cfg[(i)  name: ${(b)name}]} 
				(( pos <= $#cfg )) || return
				(( --pos ))
				for ((; pos > 0; --pos)) do
					local line=$cfg[pos] 
					if [[ $line == '- context:' ]]
					then
						return 0
					elif [[ $line == (#b)'    cluster: '($~str) ]]
					then
						cluster=$match[1] 
						[[ $cluster == $~qstr ]] && cluster=$cluster[2,-2] 
					elif [[ $line == (#b)'    namespace: '($~str) ]]
					then
						namespace=$match[1] 
						[[ $namespace == $~qstr ]] && namespace=$namespace[2,-2] 
					elif [[ $line == (#b)'    user: '($~str) ]]
					then
						user=$match[1] 
						[[ $user == $~qstr ]] && user=$user[2,-2] 
					fi
				done
			} always {
				[[ $name == $~qstr ]] && name=$name[2,-2] 
			}
		}
		if [[ -n $name ]]
		then
			: ${namespace:=default}
			if [[ $cluster == (#b)gke_(?*)_(asia|australia|europe|northamerica|southamerica|us)-([a-z]##<->)(-[a-z]|)_(?*) ]]
			then
				cloud_name=gke 
				cloud_account=$match[1] 
				cloud_zone=$match[2]-$match[3]$match[4] 
				cloud_cluster=$match[5] 
				if (( ${_POWERLEVEL9K_KUBECONTEXT_SHORTEN[(I)gke]} ))
				then
					text=$cloud_cluster 
				fi
			elif [[ $cluster == (#b)arn:aws[[:alnum:]-]#:eks:([[:alnum:]-]##):([[:digit:]]##):cluster/(?*) ]]
			then
				cloud_name=eks 
				cloud_zone=$match[1] 
				cloud_account=$match[2] 
				cloud_cluster=$match[3] 
				if (( ${_POWERLEVEL9K_KUBECONTEXT_SHORTEN[(I)eks]} ))
				then
					text=$cloud_cluster 
				fi
			fi
			if [[ -z $text ]]
			then
				text=$name 
				if [[ $_POWERLEVEL9K_KUBECONTEXT_SHOW_DEFAULT_NAMESPACE == 1 || $namespace != (default|$name) ]]
				then
					text+="/$namespace" 
				fi
			fi
			local pat class
			for pat class in "${_POWERLEVEL9K_KUBECONTEXT_CLASSES[@]}"
			do
				if [[ $text == ${~pat} ]]
				then
					[[ -n $class ]] && state=_${${(U)class}//İ/I} 
					break
				fi
			done
		fi
		_p9k_cache_stat_set "${(g::)name}" "${(g::)namespace}" "${(g::)cluster}" "${(g::)user}" "${(g::)cloud_name}" "${(g::)cloud_account}" "${(g::)cloud_zone}" "${(g::)cloud_cluster}" "${(g::)text}" "$state"
	fi
	typeset -g P9K_KUBECONTEXT_NAME=$_p9k__cache_val[1] 
	typeset -g P9K_KUBECONTEXT_NAMESPACE=$_p9k__cache_val[2] 
	typeset -g P9K_KUBECONTEXT_CLUSTER=$_p9k__cache_val[3] 
	typeset -g P9K_KUBECONTEXT_USER=$_p9k__cache_val[4] 
	typeset -g P9K_KUBECONTEXT_CLOUD_NAME=$_p9k__cache_val[5] 
	typeset -g P9K_KUBECONTEXT_CLOUD_ACCOUNT=$_p9k__cache_val[6] 
	typeset -g P9K_KUBECONTEXT_CLOUD_ZONE=$_p9k__cache_val[7] 
	typeset -g P9K_KUBECONTEXT_CLOUD_CLUSTER=$_p9k__cache_val[8] 
	[[ -n $_p9k__cache_val[9] ]] || return
	_p9k_prompt_segment $0$_p9k__cache_val[10] magenta white KUBERNETES_ICON 0 '' "${_p9k__cache_val[9]//\%/%%}"
}
prompt_laravel_version () {
	_p9k_upglob artisan && return
	local dir=$_p9k__parent_dirs[$?] 
	local app=$dir/vendor/laravel/framework/src/Illuminate/Foundation/Application.php 
	[[ -r $app ]] || return
	if ! _p9k_cache_stat_get $0 $dir/artisan $app
	then
		local v="$(php $dir/artisan --version 2> /dev/null)" 
		v="${${(M)v:#Laravel Framework *}#Laravel Framework }" 
		v=${${v#$'\e['<->m}%$'\e['<->m} 
		_p9k_cache_stat_set "$v"
	fi
	[[ -n $_p9k__cache_val[1] ]] || return
	_p9k_prompt_segment "$0" "maroon" "white" 'LARAVEL_ICON' 0 '' "${_p9k__cache_val[1]//\%/%%}"
}
prompt_lf () {
	_p9k_prompt_segment $0 6 $_p9k_color1 LF_ICON 0 '' $LF_LEVEL
}
prompt_load () {
	if [[ $_p9k_os == (OSX|BSD) ]]
	then
		local -i len=$#_p9k__prompt _p9k__has_upglob 
		_p9k_prompt_segment $0_CRITICAL red "$_p9k_color1" LOAD_ICON 1 '$_p9k__load_critical' '$_p9k__load_value'
		_p9k_prompt_segment $0_WARNING yellow "$_p9k_color1" LOAD_ICON 1 '$_p9k__load_warning' '$_p9k__load_value'
		_p9k_prompt_segment $0_NORMAL green "$_p9k_color1" LOAD_ICON 1 '$_p9k__load_normal' '$_p9k__load_value'
		(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
		return
	fi
	[[ -r /proc/loadavg ]] || return
	_p9k_read_file /proc/loadavg || return
	local load=${${(A)=_p9k__ret}[_POWERLEVEL9K_LOAD_WHICH]//,/.} 
	local -F pct='100. * load / _p9k_num_cpus' 
	if (( pct > _POWERLEVEL9K_LOAD_CRITICAL_PCT ))
	then
		_p9k_prompt_segment $0_CRITICAL red "$_p9k_color1" LOAD_ICON 0 '' $load
	elif (( pct > _POWERLEVEL9K_LOAD_WARNING_PCT ))
	then
		_p9k_prompt_segment $0_WARNING yellow "$_p9k_color1" LOAD_ICON 0 '' $load
	else
		_p9k_prompt_segment $0_NORMAL green "$_p9k_color1" LOAD_ICON 0 '' $load
	fi
}
prompt_luaenv () {
	if [[ -n $LUAENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)shell]} )) || return
		local v=$LUAENV_VERSION 
	else
		(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $LUAENV_DIR != (|.) ]]
		then
			[[ $LUAENV_DIR == /* ]] && local dir=$LUAENV_DIR  || local dir="$_p9k__cwd_a/$LUAENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.lua-version
					then
						(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .lua-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.lua-version
			then
				(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_LUAENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)global]} )) || return
			_p9k_luaenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_LUAENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_luaenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_LUAENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" blue "$_p9k_color1" 'LUA_ICON' 0 '' "${v//\%/%%}"
}
prompt_midnight_commander () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 $_p9k_color1 yellow MIDNIGHT_COMMANDER_ICON 0 '' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_nix_shell () {
	_p9k_prompt_segment $0 4 $_p9k_color1 NIX_SHELL_ICON 0 '' "${(M)IN_NIX_SHELL:#(pure|impure)}"
}
prompt_nnn () {
	_p9k_prompt_segment $0 6 $_p9k_color1 NNN_ICON 0 '' $NNNLVL
}
prompt_node_version () {
	_p9k_upglob package.json -.
	local -i idx=$? 
	(( idx || ! _POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY )) || return
	local node=$commands[node] 
	local -a file_deps env_deps
	if [[ $node == ${NODENV_ROOT:-$HOME/.nodenv}/shims/node ]]
	then
		env_deps+=("$NODENV_VERSION") 
		file_deps+=(${NODENV_ROOT:-$HOME/.nodenv}/version) 
		if [[ $NODENV_DIR != (|.) ]]
		then
			[[ $NODENV_DIR == /* ]] && local dir=$NODENV_DIR  || local dir="$_p9k__cwd_a/$NODENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if [[ -e $dir/.node-version ]]
					then
						file_deps+=($dir/.node-version) 
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		_p9k_upglob .node-version -. || file_deps+=($_p9k__parent_dirs[idx]/.node-version) 
	elif (( idx ))
	then
		file_deps+=($_p9k__parent_dirs[idx]/package.json) 
	fi
	if ! _p9k_cache_stat_get "$0 $#env_deps ${(j: :)${(@q)env_deps}} ${(j: :)${(@q)file_deps}}" $file_deps $node
	then
		local out
		out=$($node --version 2>/dev/null) 
		_p9k_cache_stat_set $(( ! $? )) "$out"
	fi
	(( $_p9k__cache_val[1] )) || return
	local v=$_p9k__cache_val[2] 
	[[ $v == v?* ]] || return
	_p9k_prompt_segment "$0" "green" "white" 'NODE_ICON' 0 '' "${${v#v}//\%/%%}"
}
prompt_nodeenv () {
	local msg
	if (( _POWERLEVEL9K_NODEENV_SHOW_NODE_VERSION )) && _p9k_cached_cmd 0 '' node --version
	then
		msg="${_p9k__ret//\%/%%} " 
	fi
	msg+="$_POWERLEVEL9K_NODEENV_LEFT_DELIMITER${${NODE_VIRTUAL_ENV:t}//\%/%%}$_POWERLEVEL9K_NODEENV_RIGHT_DELIMITER" 
	_p9k_prompt_segment "$0" "black" "green" 'NODE_ICON' 0 '' "$msg"
}
prompt_nodenv () {
	if [[ -n $NODENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)shell]} )) || return
		local v=$NODENV_VERSION 
	else
		(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $NODENV_DIR != (|.) ]]
		then
			[[ $NODENV_DIR == /* ]] && local dir=$NODENV_DIR  || local dir="$_p9k__cwd_a/$NODENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.node-version
					then
						(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .node-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.node-version
			then
				(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_NODENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)global]} )) || return
			_p9k_nodenv_global_version
		fi
		_p9k_nodeenv_version_transform $_p9k__ret || return
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_NODENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_nodenv_global_version
		_p9k_nodeenv_version_transform $_p9k__ret && [[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_NODENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "black" "green" 'NODE_ICON' 0 '' "${v//\%/%%}"
}
prompt_nordvpn () {
	return
	unset $__p9k_nordvpn_tag P9K_NORDVPN_COUNTRY_CODE
	[[ -e /run/nordvpn/nordvpnd.sock ]] || return
	_p9k_fetch_nordvpn_status 2> /dev/null || return
	if [[ $P9K_NORDVPN_SERVER == (#b)([[:alpha:]]##)[[:digit:]]##.nordvpn.com ]]
	then
		typeset -g P9K_NORDVPN_COUNTRY_CODE=${${(U)match[1]}//İ/I} 
	fi
	case $P9K_NORDVPN_STATUS in
		(Connected) _p9k_prompt_segment $0_CONNECTED blue white NORDVPN_ICON 0 '' "$P9K_NORDVPN_COUNTRY_CODE" ;;
		(Disconnected | Connecting | Disconnecting) local state=${${(U)P9K_NORDVPN_STATUS}//İ/I} 
			_p9k_get_icon $0_$state FAIL_ICON
			_p9k_prompt_segment $0_$state yellow white NORDVPN_ICON 0 '' "$_p9k__ret" ;;
		(*) return ;;
	esac
}
prompt_nvm () {
	[[ -n $NVM_DIR ]] && _p9k_nvm_ls_current || return
	local current=$_p9k__ret 
	(( _POWERLEVEL9K_NVM_SHOW_SYSTEM )) || [[ $current != system ]] || return
	(( _POWERLEVEL9K_NVM_PROMPT_ALWAYS_SHOW )) || ! _p9k_nvm_ls_default || [[ $_p9k__ret != $current ]] || return
	_p9k_prompt_segment "$0" "magenta" "black" 'NODE_ICON' 0 '' "${${current#v}//\%/%%}"
}
prompt_openfoam () {
	if [[ -z "$WM_FORK" ]]
	then
		_p9k_prompt_segment "$0" "yellow" "$_p9k_color1" '' 0 '' "OF: ${${WM_PROJECT_VERSION:t}//\%/%%}"
	else
		_p9k_prompt_segment "$0" "yellow" "$_p9k_color1" '' 0 '' "F-X: ${${WM_PROJECT_VERSION:t}//\%/%%}"
	fi
}
prompt_os_icon () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "black" "white" '' 0 '' "$_p9k_os_icon"
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_package () {
	unset P9K_PACKAGE_NAME P9K_PACKAGE_VERSION
	_p9k_upglob package.json -. && return
	local file=$_p9k__parent_dirs[$?]/package.json 
	if ! _p9k_cache_stat_get $0 $file
	then
		() {
			local data field
			local -A found
			{
				data="$(<$file)"  || return
			} 2> /dev/null
			data=${${data//$'\r'}##[[:space:]]#} 
			[[ $data == '{'* ]] || return
			data[1]= 
			local -i depth=1 
			while true
			do
				data=${data##[[:space:]]#} 
				[[ -n $data ]] || return
				case $data[1] in
					('{' | '[') data[1]= 
						(( ++depth )) ;;
					('}' | ']') data[1]= 
						(( --depth > 0 )) || return ;;
					(':') data[1]=  ;;
					(',') data[1]= 
						field=  ;;
					([[:alnum:].]) data=${data##[[:alnum:].]#}  ;;
					('"') local tail=${data##\"([^\"\\]|\\?)#} 
						[[ $tail == '"'* ]] || return
						local s=${data:1:-$#tail} 
						data=${tail:1} 
						(( depth == 1 )) || continue
						if [[ -z $field ]]
						then
							field=${s:-x} 
						elif [[ $field == (name|version) ]]
						then
							(( ! $+found[$field] )) || return
							[[ -n $s ]] || return
							[[ $s != *($'\n'|'\')* ]] || return
							found[$field]=$s 
							(( $#found == 2 )) && break
						fi ;;
					(*) return 1 ;;
				esac
			done
			_p9k_cache_stat_set 1 $found[name] $found[version]
			return 0
		} || _p9k_cache_stat_set 0
	fi
	(( _p9k__cache_val[1] )) || return
	P9K_PACKAGE_NAME=$_p9k__cache_val[2] 
	P9K_PACKAGE_VERSION=$_p9k__cache_val[3] 
	_p9k_prompt_segment "$0" "cyan" "$_p9k_color1" PACKAGE_ICON 0 '' ${P9K_PACKAGE_VERSION//\%/%%}
}
prompt_per_directory_history () {
	if [[ $_per_directory_history_is_global == true ]]
	then
		_p9k_prompt_segment ${0}_GLOBAL 3 $_p9k_color1 HISTORY_ICON 0 '' global
	else
		_p9k_prompt_segment ${0}_LOCAL 5 $_p9k_color1 HISTORY_ICON 0 '' local
	fi
}
prompt_perlbrew () {
	if (( _POWERLEVEL9K_PERLBREW_PROJECT_ONLY ))
	then
		_p9k_upglob 'cpanfile|.perltidyrc|(|MY)META.(yml|json)|(Makefile|Build).PL|*.(pl|pm|t|pod)' -. && return
	fi
	local v=$PERLBREW_PERL 
	(( _POWERLEVEL9K_PERLBREW_SHOW_PREFIX )) || v=${v#*-} 
	[[ -n $v ]] || return
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PERL_ICON' 0 '' "${v//\%/%%}"
}
prompt_php_version () {
	if (( _POWERLEVEL9K_PHP_VERSION_PROJECT_ONLY ))
	then
		_p9k_upglob 'composer.json|*.php' -. && return
	fi
	_p9k_cached_cmd 0 '' php --version || return
	[[ $_p9k__ret == (#b)(*$'\n')#'PHP '([[:digit:].]##)* ]] || return
	local v=$match[2] 
	_p9k_prompt_segment "$0" "fuchsia" "grey93" 'PHP_ICON' 0 '' "${v//\%/%%}"
}
prompt_phpenv () {
	if [[ -n $PHPENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)shell]} )) || return
		local v=$PHPENV_VERSION 
	else
		(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $PHPENV_DIR != (|.) ]]
		then
			[[ $PHPENV_DIR == /* ]] && local dir=$PHPENV_DIR  || local dir="$_p9k__cwd_a/$PHPENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.php-version
					then
						(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .php-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.php-version
			then
				(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_PHPENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)global]} )) || return
			_p9k_phpenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_PHPENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_phpenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_PHPENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "magenta" "$_p9k_color1" 'PHP_ICON' 0 '' "${v//\%/%%}"
}
prompt_plenv () {
	if [[ -n $PLENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)shell]} )) || return
		local v=$PLENV_VERSION 
	else
		(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $PLENV_DIR != (|.) ]]
		then
			[[ $PLENV_DIR == /* ]] && local dir=$PLENV_DIR  || local dir="$_p9k__cwd_a/$PLENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.perl-version
					then
						(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .perl-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.perl-version
			then
				(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_PLENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)global]} )) || return
			_p9k_plenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_PLENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_plenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_PLENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PERL_ICON' 0 '' "${v//\%/%%}"
}
prompt_powerlevel9k_setup () {
	_p9k_restore_special_params
	eval "$__p9k_intro"
	_p9k_setup
}
prompt_powerlevel9k_teardown () {
	_p9k_restore_special_params
	eval "$__p9k_intro"
	add-zsh-hook -D precmd '(_p9k_|powerlevel9k_)*'
	add-zsh-hook -D preexec '(_p9k_|powerlevel9k_)*'
	PROMPT='%m%# ' 
	RPROMPT= 
	if (( __p9k_enabled ))
	then
		_p9k_deinit
		__p9k_enabled=0 
	fi
}
prompt_prompt_char () {
	local saved=$_p9k__prompt_char_saved[$_p9k__prompt_side$_p9k__segment_index$((!_p9k__status))] 
	if [[ -n $saved ]]
	then
		_p9k__prompt+=$saved 
		return
	fi
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	if (( __p9k_sh_glob ))
	then
		if (( _p9k__status ))
		then
			if (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
			then
				_p9k_prompt_segment $0_ERROR_VIINS "$_p9k_color1" 196 '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*overwrite*}}' '❯'
				_p9k_prompt_segment $0_ERROR_VIOWR "$_p9k_color1" 196 '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*insert*}}' '▶'
			else
				_p9k_prompt_segment $0_ERROR_VIINS "$_p9k_color1" 196 '' 0 '${${${${_p9k__keymap:#vicmd}:#vivis}:#vivli}}' '❯'
			fi
			_p9k_prompt_segment $0_ERROR_VICMD "$_p9k_color1" 196 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' '❮'
			_p9k_prompt_segment $0_ERROR_VIVIS "$_p9k_color1" 196 '' 0 '${$((! ${#${${${${:-$_p9k__keymap$_p9k__region_active}:#vicmd1}:#vivis?}:#vivli?}})):#0}' 'Ⅴ'
		else
			if (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
			then
				_p9k_prompt_segment $0_OK_VIINS "$_p9k_color1" 76 '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*overwrite*}}' '❯'
				_p9k_prompt_segment $0_OK_VIOWR "$_p9k_color1" 76 '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*insert*}}' '▶'
			else
				_p9k_prompt_segment $0_OK_VIINS "$_p9k_color1" 76 '' 0 '${${${${_p9k__keymap:#vicmd}:#vivis}:#vivli}}' '❯'
			fi
			_p9k_prompt_segment $0_OK_VICMD "$_p9k_color1" 76 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' '❮'
			_p9k_prompt_segment $0_OK_VIVIS "$_p9k_color1" 76 '' 0 '${$((! ${#${${${${:-$_p9k__keymap$_p9k__region_active}:#vicmd1}:#vivis?}:#vivli?}})):#0}' 'Ⅴ'
		fi
	else
		if (( _p9k__status ))
		then
			if (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
			then
				_p9k_prompt_segment $0_ERROR_VIINS "$_p9k_color1" 196 '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*overwrite*)}' '❯'
				_p9k_prompt_segment $0_ERROR_VIOWR "$_p9k_color1" 196 '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*insert*)}' '▶'
			else
				_p9k_prompt_segment $0_ERROR_VIINS "$_p9k_color1" 196 '' 0 '${_p9k__keymap:#(vicmd|vivis|vivli)}' '❯'
			fi
			_p9k_prompt_segment $0_ERROR_VICMD "$_p9k_color1" 196 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' '❮'
			_p9k_prompt_segment $0_ERROR_VIVIS "$_p9k_color1" 196 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#(vicmd1|vivis?|vivli?)}' 'Ⅴ'
		else
			if (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
			then
				_p9k_prompt_segment $0_OK_VIINS "$_p9k_color1" 76 '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*overwrite*)}' '❯'
				_p9k_prompt_segment $0_OK_VIOWR "$_p9k_color1" 76 '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*insert*)}' '▶'
			else
				_p9k_prompt_segment $0_OK_VIINS "$_p9k_color1" 76 '' 0 '${_p9k__keymap:#(vicmd|vivis|vivli)}' '❯'
			fi
			_p9k_prompt_segment $0_OK_VICMD "$_p9k_color1" 76 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' '❮'
			_p9k_prompt_segment $0_OK_VIVIS "$_p9k_color1" 76 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#(vicmd1|vivis?|vivli?)}' 'Ⅴ'
		fi
	fi
	(( _p9k__has_upglob )) || _p9k__prompt_char_saved[$_p9k__prompt_side$_p9k__segment_index$((!_p9k__status))]=$_p9k__prompt[len+1,-1] 
}
prompt_proxy () {
	local -U p=($all_proxy $http_proxy $https_proxy $ftp_proxy $ALL_PROXY $HTTP_PROXY $HTTPS_PROXY $FTP_PROXY) 
	p=(${(@)${(@)${(@)p#*://}##*@}%%/*}) 
	(( $#p == 1 )) || p=("") 
	_p9k_prompt_segment $0 $_p9k_color1 blue PROXY_ICON 0 '' "$p[1]"
}
prompt_public_ip () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	local ip='${_p9k__public_ip:-$_POWERLEVEL9K_PUBLIC_IP_NONE}' 
	if [[ -n $_POWERLEVEL9K_PUBLIC_IP_VPN_INTERFACE ]]
	then
		_p9k_prompt_segment "$0" "$_p9k_color1" "$_p9k_color2" PUBLIC_IP_ICON 1 '${_p9k__public_ip_not_vpn:+'$ip'}' $ip
		_p9k_prompt_segment "$0" "$_p9k_color1" "$_p9k_color2" VPN_ICON 1 '${_p9k__public_ip_vpn:+'$ip'}' $ip
	else
		_p9k_prompt_segment "$0" "$_p9k_color1" "$_p9k_color2" PUBLIC_IP_ICON 1 $ip $ip
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_pyenv () {
	_p9k_pyenv_compute || return
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '' "${_p9k__pyenv_version//\%/%%}"
}
prompt_ram () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 yellow "$_p9k_color1" RAM_ICON 1 '$_p9k__ram_free' '$_p9k__ram_free'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_ranger () {
	_p9k_prompt_segment $0 $_p9k_color1 yellow RANGER_ICON 0 '' $RANGER_LEVEL
}
prompt_rbenv () {
	if [[ -n $RBENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)shell]} )) || return
		local v=$RBENV_VERSION 
	else
		(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $RBENV_DIR != (|.) ]]
		then
			[[ $RBENV_DIR == /* ]] && local dir=$RBENV_DIR  || local dir="$_p9k__cwd_a/$RBENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.ruby-version
					then
						(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .ruby-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.ruby-version
			then
				(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)global]} )) || return
			_p9k_rbenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_rbenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_RBENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "red" "$_p9k_color1" 'RUBY_ICON' 0 '' "${v//\%/%%}"
}
prompt_root_indicator () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "$_p9k_color1" "yellow" 'ROOT_ICON' 0 '${${(%):-%#}:#\%}' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_rspec_stats () {
	if [[ -d app && -d spec ]]
	then
		local -a code=(app/**/*.rb(N)) 
		(( $#code )) || return
		local tests=(spec/**/*.rb(N)) 
		_p9k_build_test_stats "$0" "$#code" "$#tests" "RSpec" 'TEST_ICON'
	fi
}
prompt_rust_version () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 darkorange $_p9k_color1 RUST_ICON 1 '$P9K_RUST_VERSION' '${P9K_RUST_VERSION//\%/%%}'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_rvm () {
	[[ $GEM_HOME == *rvm* && $ruby_string != $rvm_path/bin/ruby ]] || return
	local v=${GEM_HOME:t} 
	(( _POWERLEVEL9K_RVM_SHOW_GEMSET )) || v=${v%%${rvm_gemset_separator:-@}*} 
	(( _POWERLEVEL9K_RVM_SHOW_PREFIX )) || v=${v#*-} 
	[[ -n $v ]] || return
	_p9k_prompt_segment "$0" "240" "$_p9k_color1" 'RUBY_ICON' 0 '' "${v//\%/%%}"
}
prompt_scalaenv () {
	if [[ -n $SCALAENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)shell]} )) || return
		local v=$SCALAENV_VERSION 
	else
		(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $SCALAENV_DIR != (|.) ]]
		then
			[[ $SCALAENV_DIR == /* ]] && local dir=$SCALAENV_DIR  || local dir="$_p9k__cwd_a/$SCALAENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.scala-version
					then
						(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .scala-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.scala-version
			then
				(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_SCALAENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)global]} )) || return
			_p9k_scalaenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_SCALAENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_scalaenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_SCALAENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "red" "$_p9k_color1" 'SCALA_ICON' 0 '' "${v//\%/%%}"
}
prompt_ssh () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "$_p9k_color1" "yellow" 'SSH_ICON' 0 '' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_starship_precmd () {
	STARSHIP_CMD_STATUS=$? STARSHIP_PIPE_STATUS=(${pipestatus[@]}) 
	if (( ${+STARSHIP_START_TIME} ))
	then
		__starship_get_time && STARSHIP_DURATION=$(( STARSHIP_CAPTURED_TIME - STARSHIP_START_TIME )) 
		unset STARSHIP_START_TIME
	else
		unset STARSHIP_DURATION STARSHIP_CMD_STATUS STARSHIP_PIPE_STATUS
	fi
	STARSHIP_JOBS_COUNT="${#jobstates[*]}" 
}
prompt_starship_preexec () {
	__starship_get_time && STARSHIP_START_TIME=$STARSHIP_CAPTURED_TIME 
}
prompt_status () {
	if ! _p9k_cache_get $0 $_p9k__status $_p9k__pipestatus
	then
		(( _p9k__status )) && local state=ERROR  || local state=OK 
		if (( _POWERLEVEL9K_STATUS_EXTENDED_STATES ))
		then
			if (( _p9k__status ))
			then
				if (( $#_p9k__pipestatus > 1 ))
				then
					state+=_PIPE 
				elif (( _p9k__status > 128 ))
				then
					state+=_SIGNAL 
				fi
			elif [[ "$_p9k__pipestatus" == *[1-9]* ]]
			then
				state+=_PIPE 
			fi
		fi
		_p9k__cache_val=(:) 
		if (( _POWERLEVEL9K_STATUS_$state ))
		then
			if (( _POWERLEVEL9K_STATUS_SHOW_PIPESTATUS ))
			then
				local text=${(j:|:)${(@)_p9k__pipestatus:/(#b)(*)/$_p9k_exitcode2str[$match[1]+1]}} 
			else
				local text=$_p9k_exitcode2str[_p9k__status+1] 
			fi
			if (( _p9k__status ))
			then
				if (( !_POWERLEVEL9K_STATUS_CROSS && _POWERLEVEL9K_STATUS_VERBOSE ))
				then
					_p9k__cache_val=($0_$state red yellow1 CARRIAGE_RETURN_ICON 0 '' "$text") 
				else
					_p9k__cache_val=($0_$state $_p9k_color1 red FAIL_ICON 0 '' '') 
				fi
			elif (( _POWERLEVEL9K_STATUS_VERBOSE || _POWERLEVEL9K_STATUS_OK_IN_NON_VERBOSE ))
			then
				[[ $state == OK ]] && text='' 
				_p9k__cache_val=($0_$state "$_p9k_color1" green OK_ICON 0 '' "$text") 
			fi
		fi
		if (( $#_p9k__pipestatus < 3 ))
		then
			_p9k_cache_set "${(@)_p9k__cache_val}"
		fi
	fi
	_p9k_prompt_segment "${(@)_p9k__cache_val}"
}
prompt_swap () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 yellow "$_p9k_color1" SWAP_ICON 1 '$_p9k__swap_used' '$_p9k__swap_used'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_swift_version () {
	_p9k_cached_cmd 0 '' swift --version || return
	[[ $_p9k__ret == (#b)[^[:digit:]]#([[:digit:].]##)* ]] || return
	_p9k_prompt_segment "$0" "magenta" "white" 'SWIFT_ICON' 0 '' "${match[1]//\%/%%}"
}
prompt_symfony2_tests () {
	if [[ -d src && -d app && -f app/AppKernel.php ]]
	then
		local -a all=(src/**/*.php(N)) 
		local -a code=(${(@)all##*Tests*}) 
		(( $#code )) || return
		_p9k_build_test_stats "$0" "$#code" "$(($#all - $#code))" "SF2" 'TEST_ICON'
	fi
}
prompt_symfony2_version () {
	if [[ -r app/bootstrap.php.cache ]]
	then
		local v="${$(grep -F " VERSION " app/bootstrap.php.cache 2>/dev/null)//[![:digit:].]}" 
		_p9k_prompt_segment "$0" "grey35" "$_p9k_color1" 'SYMFONY_ICON' 0 '' "${v//\%/%%}"
	fi
}
prompt_taskwarrior () {
	unset P9K_TASKWARRIOR_PENDING_COUNT P9K_TASKWARRIOR_OVERDUE_COUNT
	if ! _p9k_taskwarrior_check_data
	then
		_p9k_taskwarrior_data_files=() 
		_p9k_taskwarrior_data_non_files=() 
		_p9k_taskwarrior_data_sig= 
		_p9k_taskwarrior_counters=() 
		_p9k_taskwarrior_next_due=0 
		_p9k_taskwarrior_check_meta || _p9k_taskwarrior_init_meta || return
		_p9k_taskwarrior_init_data
	fi
	(( $#_p9k_taskwarrior_counters )) || return
	local text c=$_p9k_taskwarrior_counters[OVERDUE] 
	if [[ -n $c ]]
	then
		typeset -g P9K_TASKWARRIOR_OVERDUE_COUNT=$c 
		text+="!$c" 
	fi
	c=$_p9k_taskwarrior_counters[PENDING] 
	if [[ -n $c ]]
	then
		typeset -g P9K_TASKWARRIOR_PENDING_COUNT=$c 
		[[ -n $text ]] && text+='/' 
		text+=$c 
	fi
	[[ -n $text ]] || return
	_p9k_prompt_segment $0 6 $_p9k_color1 TASKWARRIOR_ICON 0 '' $text
}
prompt_terraform () {
	local ws=$TF_WORKSPACE 
	if [[ -z $TF_WORKSPACE ]]
	then
		_p9k_read_word ${${TF_DATA_DIR:-.terraform}:A}/environment && ws=$_p9k__ret 
	fi
	[[ -z $ws || ( $ws == default && $_POWERLEVEL9K_TERRAFORM_SHOW_DEFAULT == 0 ) ]] && return
	local pat class state
	for pat class in "${_POWERLEVEL9K_TERRAFORM_CLASSES[@]}"
	do
		if [[ $ws == ${~pat} ]]
		then
			[[ -n $class ]] && state=_${${(U)class}//İ/I} 
			break
		fi
	done
	_p9k_prompt_segment "$0$state" $_p9k_color1 blue TERRAFORM_ICON 0 '' $ws
}
prompt_terraform_version () {
	local v cfg terraform=${commands[terraform]} 
	_p9k_upglob .terraform-version -. || cfg=$_p9k__parent_dirs[$?]/.terraform-version 
	if _p9k_cache_stat_get $0.$TFENV_TERRAFORM_VERSION $terraform $cfg
	then
		v=$_p9k__cache_val[1] 
	else
		v=${${"$(terraform --version 2>/dev/null)"#Terraform v}%%$'\n'*}  || v= 
		_p9k_cache_stat_set "$v"
	fi
	[[ -n $v ]] || return
	_p9k_prompt_segment $0 $_p9k_color1 blue TERRAFORM_ICON 0 '' ${v//\%/%%}
}
prompt_time () {
	if (( _POWERLEVEL9K_EXPERIMENTAL_TIME_REALTIME ))
	then
		_p9k_prompt_segment "$0" "$_p9k_color2" "$_p9k_color1" "TIME_ICON" 0 '' "$_POWERLEVEL9K_TIME_FORMAT"
	else
		if [[ $_p9k__refresh_reason == precmd ]]
		then
			if [[ $+__p9k_instant_prompt_active == 1 && $__p9k_instant_prompt_time_format == $_POWERLEVEL9K_TIME_FORMAT ]]
			then
				_p9k__time=${__p9k_instant_prompt_time//\%/%%} 
			else
				_p9k__time=${${(%)_POWERLEVEL9K_TIME_FORMAT}//\%/%%} 
			fi
		fi
		if (( _POWERLEVEL9K_TIME_UPDATE_ON_COMMAND ))
		then
			_p9k_escape $_p9k__time
			local t=$_p9k__ret 
			_p9k_escape $_POWERLEVEL9K_TIME_FORMAT
			_p9k_prompt_segment "$0" "$_p9k_color2" "$_p9k_color1" "TIME_ICON" 1 '' "\${_p9k__line_finished-$t}\${_p9k__line_finished+$_p9k__ret}"
		else
			_p9k_prompt_segment "$0" "$_p9k_color2" "$_p9k_color1" "TIME_ICON" 0 '' $_p9k__time
		fi
	fi
}
prompt_timewarrior () {
	local dir
	[[ -n ${dir::=$TIMEWARRIORDB} || -n ${dir::=~/.timewarrior}(#q-/N) ]] || dir=${XDG_DATA_HOME:-~/.local/share}/timewarrior 
	dir+=/data 
	local -a stat
	[[ $dir == $_p9k_timewarrior_dir ]] || _p9k_timewarrior_clear
	if [[ -n $_p9k_timewarrior_file_name ]]
	then
		zstat -A stat +mtime -- $dir $_p9k_timewarrior_file_name 2> /dev/null || stat=() 
		if [[ $stat[1] == $_p9k_timewarrior_dir_mtime && $stat[2] == $_p9k_timewarrior_file_mtime ]]
		then
			if (( $+_p9k_timewarrior_tags ))
			then
				_p9k_prompt_segment $0 grey 255 TIMEWARRIOR_ICON 0 '' "${_p9k_timewarrior_tags//\%/%%}"
			fi
			return
		fi
	fi
	if [[ ! -d $dir ]]
	then
		_p9k_timewarrior_clear
		return
	fi
	_p9k_timewarrior_dir=$dir 
	if [[ $stat[1] != $_p9k_timewarrior_dir_mtime ]]
	then
		local -a files=($dir/<->-<->.data(.N)) 
		if (( ! $#files ))
		then
			if (( $#stat )) || zstat -A stat +mtime -- $dir 2> /dev/null
			then
				_p9k_timewarrior_dir_mtime=$stat[1] 
				_p9k_timewarrior_file_mtime=$stat[1] 
				_p9k_timewarrior_file_name=$dir 
				unset _p9k_timewarrior_tags
				_p9k__state_dump_scheduled=1 
			else
				_p9k_timewarrior_clear
			fi
			return
		fi
		_p9k_timewarrior_file_name=${${(AO)files}[1]} 
	fi
	if ! zstat -A stat +mtime -- $dir $_p9k_timewarrior_file_name 2> /dev/null
	then
		_p9k_timewarrior_clear
		return
	fi
	_p9k_timewarrior_dir_mtime=$stat[1] 
	_p9k_timewarrior_file_mtime=$stat[2] 
	{
		local tail=${${(Af)"$(<$_p9k_timewarrior_file_name)"}[-1]} 
	} 2> /dev/null
	if [[ $tail == (#b)'inc '[^\ ]##(|\ #\#(*)) ]]
	then
		_p9k_timewarrior_tags=${${match[2]## #}%% #} 
		_p9k_prompt_segment $0 grey 255 TIMEWARRIOR_ICON 0 '' "${_p9k_timewarrior_tags//\%/%%}"
	else
		unset _p9k_timewarrior_tags
	fi
	_p9k__state_dump_scheduled=1 
}
prompt_todo () {
	unset P9K_TODO_TOTAL_TASK_COUNT P9K_TODO_FILTERED_TASK_COUNT
	[[ -r $_p9k__todo_file && -x $_p9k__todo_command ]] || return
	if ! _p9k_cache_stat_get $0 $_p9k__todo_file
	then
		local count="$($_p9k__todo_command -p ls | command tail -1)" 
		if [[ $count == (#b)'TODO: '([[:digit:]]##)' of '([[:digit:]]##)' '* ]]
		then
			_p9k_cache_stat_set 1 $match[1] $match[2]
		else
			_p9k_cache_stat_set 0
		fi
	fi
	(( $_p9k__cache_val[1] )) || return
	typeset -gi P9K_TODO_FILTERED_TASK_COUNT=$_p9k__cache_val[2] 
	typeset -gi P9K_TODO_TOTAL_TASK_COUNT=$_p9k__cache_val[3] 
	if (( (P9K_TODO_TOTAL_TASK_COUNT    || !_POWERLEVEL9K_TODO_HIDE_ZERO_TOTAL) &&
        (P9K_TODO_FILTERED_TASK_COUNT || !_POWERLEVEL9K_TODO_HIDE_ZERO_FILTERED) ))
	then
		if (( P9K_TODO_TOTAL_TASK_COUNT == P9K_TODO_FILTERED_TASK_COUNT ))
		then
			local text=$P9K_TODO_TOTAL_TASK_COUNT 
		else
			local text="$P9K_TODO_FILTERED_TASK_COUNT/$P9K_TODO_TOTAL_TASK_COUNT" 
		fi
		_p9k_prompt_segment "$0" "grey50" "$_p9k_color1" 'TODO_ICON' 0 '' "$text"
	fi
}
prompt_toolbox () {
	_p9k_prompt_segment $0 $_p9k_color1 yellow TOOLBOX_ICON 0 '' $P9K_TOOLBOX_NAME
}
prompt_user () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "${0}_ROOT" "${_p9k_color1}" yellow ROOT_ICON 0 '${${(%):-%#}:#\%}' "$_POWERLEVEL9K_USER_TEMPLATE"
	if [[ -n "$SUDO_COMMAND" ]]
	then
		_p9k_prompt_segment "${0}_SUDO" "${_p9k_color1}" yellow SUDO_ICON 0 '${${(%):-%#}:#\#}' "$_POWERLEVEL9K_USER_TEMPLATE"
	else
		_p9k_prompt_segment "${0}_DEFAULT" "${_p9k_color1}" yellow USER_ICON 0 '${${(%):-%#}:#\#}' "%n"
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_vcs () {
	if (( _p9k_vcs_index && $+GITSTATUS_DAEMON_PID_POWERLEVEL9K ))
	then
		_p9k__prompt+='${(e)_p9k__vcs}' 
		return
	fi
	local -a backends=($_POWERLEVEL9K_VCS_BACKENDS) 
	if (( ${backends[(I)git]} && $+GITSTATUS_DAEMON_PID_POWERLEVEL9K )) && _p9k_vcs_gitstatus
	then
		_p9k_vcs_render && return
		backends=(${backends:#git}) 
	fi
	if (( $#backends ))
	then
		VCS_WORKDIR_DIRTY=false 
		VCS_WORKDIR_HALF_DIRTY=false 
		local current_state="" 
		zstyle ':vcs_info:*' enable ${backends}
		vcs_info
		local vcs_prompt="${vcs_info_msg_0_}" 
		if [[ -n "$vcs_prompt" ]]
		then
			if [[ "$VCS_WORKDIR_DIRTY" == true ]]
			then
				current_state='MODIFIED' 
			else
				if [[ "$VCS_WORKDIR_HALF_DIRTY" == true ]]
				then
					current_state='UNTRACKED' 
				else
					current_state='CLEAN' 
				fi
			fi
			_p9k_prompt_segment "${0}_${${(U)current_state}//İ/I}" "${__p9k_vcs_states[$current_state]}" "$_p9k_color1" "$vcs_visual_identifier" 0 '' "$vcs_prompt"
		fi
	fi
}
prompt_vi_mode () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	if (( __p9k_sh_glob ))
	then
		if (( $+_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING ))
		then
			if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
			then
				_p9k_prompt_segment $0_INSERT "$_p9k_color1" blue '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*overwrite*}}' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
			fi
			_p9k_prompt_segment $0_OVERWRITE "$_p9k_color1" blue '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*insert*}}' "$_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING"
		else
			if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
			then
				_p9k_prompt_segment $0_INSERT "$_p9k_color1" blue '' 0 '${${${${_p9k__keymap:#vicmd}:#vivis}:#vivli}}' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
			fi
		fi
		if (( $+_POWERLEVEL9K_VI_VISUAL_MODE_STRING ))
		then
			_p9k_prompt_segment $0_NORMAL "$_p9k_color1" white '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' "$_POWERLEVEL9K_VI_COMMAND_MODE_STRING"
			_p9k_prompt_segment $0_VISUAL "$_p9k_color1" white '' 0 '${$((! ${#${${${${:-$_p9k__keymap$_p9k__region_active}:#vicmd1}:#vivis?}:#vivli?}})):#0}' "$_POWERLEVEL9K_VI_VISUAL_MODE_STRING"
		else
			_p9k_prompt_segment $0_NORMAL "$_p9k_color1" white '' 0 '${$((! ${#${${${_p9k__keymap:#vicmd}:#vivis}:#vivli}})):#0}' "$_POWERLEVEL9K_VI_COMMAND_MODE_STRING"
		fi
	else
		if (( $+_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING ))
		then
			if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
			then
				_p9k_prompt_segment $0_INSERT "$_p9k_color1" blue '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*overwrite*)}' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
			fi
			_p9k_prompt_segment $0_OVERWRITE "$_p9k_color1" blue '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*insert*)}' "$_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING"
		else
			if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
			then
				_p9k_prompt_segment $0_INSERT "$_p9k_color1" blue '' 0 '${_p9k__keymap:#(vicmd|vivis|vivli)}' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
			fi
		fi
		if (( $+_POWERLEVEL9K_VI_VISUAL_MODE_STRING ))
		then
			_p9k_prompt_segment $0_NORMAL "$_p9k_color1" white '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' "$_POWERLEVEL9K_VI_COMMAND_MODE_STRING"
			_p9k_prompt_segment $0_VISUAL "$_p9k_color1" white '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#(vicmd1|vivis?|vivli?)}' "$_POWERLEVEL9K_VI_VISUAL_MODE_STRING"
		else
			_p9k_prompt_segment $0_NORMAL "$_p9k_color1" white '' 0 '${(M)_p9k__keymap:#(vicmd|vivis|vivli)}' "$_POWERLEVEL9K_VI_COMMAND_MODE_STRING"
		fi
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_vim_shell () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 green $_p9k_color1 VIM_ICON 0 '' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_virtualenv () {
	local msg='' 
	if (( _POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION )) && _p9k_python_version
	then
		msg="${_p9k__ret//\%/%%} " 
	fi
	local cfg=$VIRTUAL_ENV/pyvenv.cfg 
	if ! _p9k_cache_stat_get $0 $cfg
	then
		local -a reply
		_p9k_parse_virtualenv_cfg $cfg
		_p9k_cache_stat_set "${reply[@]}"
	fi
	if (( _p9k__cache_val[1] ))
	then
		local v=$_p9k__cache_val[2] 
	else
		local v=${VIRTUAL_ENV:t} 
		if [[ $VIRTUAL_ENV_PROMPT == '('?*') ' && $VIRTUAL_ENV_PROMPT != "($v) " ]]
		then
			v=$VIRTUAL_ENV_PROMPT[2,-3] 
		elif [[ $v == $~_POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES ]]
		then
			v=${VIRTUAL_ENV:h:t} 
		fi
	fi
	msg+="$_POWERLEVEL9K_VIRTUALENV_LEFT_DELIMITER${v//\%/%%}$_POWERLEVEL9K_VIRTUALENV_RIGHT_DELIMITER" 
	case $_POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV in
		(false) _p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '${(M)${#P9K_PYENV_PYTHON_VERSION}:#0}' "$msg" ;;
		(if-different) _p9k_escape $v
			_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '${${:-'$_p9k__ret'}:#$_p9k__pyenv_version}' "$msg" ;;
		(*) _p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '' "$msg" ;;
	esac
}
prompt_vpn_ip () {
	typeset -ga _p9k__vpn_ip_segments
	_p9k__vpn_ip_segments+=($_p9k__prompt_side $_p9k__line_index $_p9k__segment_index) 
	local p='${(e)_p9k__vpn_ip_'$_p9k__prompt_side$_p9k__segment_index'}' 
	_p9k__prompt+=$p 
	typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$p
}
prompt_wifi () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 green $_p9k_color1 WIFI_ICON 1 '$_p9k__wifi_on' '$P9K_WIFI_LAST_TX_RATE Mbps'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_xplr () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 6 $_p9k_color1 XPLR_ICON 0 '' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_yazi () {
	_p9k_prompt_segment $0 $_p9k_color1 yellow YAZI_ICON 0 '' $YAZI_LEVEL
}
pyenv_prompt_info () {
	return 1
}
rbenv_prompt_info () {
	return 1
}
regexp-replace () {
	argv=("$1" "$2" "$3") 
	4=0 
	[[ -o re_match_pcre ]] && 4=1 
	emulate -L zsh
	local MATCH MBEGIN MEND
	local -a match mbegin mend
	if (( $4 ))
	then
		zmodload zsh/pcre || return 2
		pcre_compile -- "$2" && pcre_study || return 2
		4=0 6= 
		local ZPCRE_OP
		while pcre_match -b -n $4 -- "${(P)1}"
		do
			5=${(e)3} 
			argv+=(${(s: :)ZPCRE_OP} "$5") 
			4=$((argv[-2] + (argv[-3] == argv[-2]))) 
		done
		(($# > 6)) || return
		set +o multibyte
		5= 6=1 
		for 2 3 4 in "$@[7,-1]"
		do
			5+=${(P)1[$6,$2]}$4 
			6=$(($3 + 1)) 
		done
		5+=${(P)1[$6,-1]} 
	else
		4=${(P)1} 
		while [[ -n $4 ]]
		do
			if [[ $4 =~ $2 ]]
			then
				5+=${4[1,MBEGIN-1]}${(e)3} 
				if ((MEND < MBEGIN))
				then
					((MEND++))
					5+=${4[1]} 
				fi
				4=${4[MEND+1,-1]} 
				6=1 
			else
				break
			fi
		done
		[[ -n $6 ]] || return
		5+=$4 
	fi
	eval $1=\$5
}
ruby_prompt_info () {
	echo "$(rvm_prompt_info || rbenv_prompt_info || chruby_prompt_info)"
}
rvm_prompt_info () {
	[ -f $HOME/.rvm/bin/rvm-prompt ] || return 1
	local rvm_prompt
	rvm_prompt=$($HOME/.rvm/bin/rvm-prompt ${=ZSH_THEME_RVM_PROMPT_OPTIONS} 2>/dev/null) 
	[[ -z "${rvm_prompt}" ]] && return 1
	echo "${ZSH_THEME_RUBY_PROMPT_PREFIX}${rvm_prompt:gs/%/%%}${ZSH_THEME_RUBY_PROMPT_SUFFIX}"
}
spectrum_bls () {
	setopt localoptions nopromptsubst
	local ZSH_SPECTRUM_TEXT=${ZSH_SPECTRUM_TEXT:-Arma virumque cano Troiae qui primus ab oris} 
	for code in {000..255}
	do
		print -P -- "$code: ${BG[$code]}${ZSH_SPECTRUM_TEXT}%{$reset_color%}"
	done
}
spectrum_ls () {
	setopt localoptions nopromptsubst
	local ZSH_SPECTRUM_TEXT=${ZSH_SPECTRUM_TEXT:-Arma virumque cano Troiae qui primus ab oris} 
	for code in {000..255}
	do
		print -P -- "$code: ${FG[$code]}${ZSH_SPECTRUM_TEXT}%{$reset_color%}"
	done
}
starship_zle-keymap-select () {
	zle reset-prompt
}
svn_prompt_info () {
	return 1
}
take () {
	if [[ $1 =~ ^(https?|ftp).*\.(tar\.(gz|bz2|xz)|tgz)$ ]]
	then
		takeurl "$1"
	elif [[ $1 =~ ^(https?|ftp).*\.(zip)$ ]]
	then
		takezip "$1"
	elif [[ $1 =~ ^([A-Za-z0-9]\+@|https?|git|ssh|ftps?|rsync).*\.git/?$ ]]
	then
		takegit "$1"
	else
		takedir "$@"
	fi
}
takedir () {
	mkdir -p $@ && cd ${@:$#}
}
takegit () {
	git clone "$1"
	cd "$(basename ${1%%.git})"
}
takeurl () {
	local data thedir
	data="$(mktemp)" 
	curl -L "$1" > "$data"
	tar xf "$data"
	thedir="$(tar tf "$data" | head -n 1)" 
	rm "$data"
	cd "$thedir"
}
takezip () {
	local data thedir
	data="$(mktemp)" 
	curl -L "$1" > "$data"
	unzip "$data" -d "./"
	thedir="$(unzip -l "$data" | awk 'NR==4 {print $4}' | sed 's/\/.*//')" 
	rm "$data"
	cd "$thedir"
}
tf_prompt_info () {
	return 1
}
title () {
	setopt localoptions nopromptsubst
	[[ -n "${INSIDE_EMACS:-}" && "$INSIDE_EMACS" != vterm ]] && return
	: ${2=$1}
	case "$TERM" in
		(cygwin | xterm* | putty* | rxvt* | konsole* | ansi | mlterm* | alacritty* | st* | foot* | contour* | wezterm*) print -Pn "\e]2;${2:q}\a"
			print -Pn "\e]1;${1:q}\a" ;;
		(screen* | tmux*) print -Pn "\ek${1:q}\e\\" ;;
		(*) if [[ "$TERM_PROGRAM" == "iTerm.app" ]]
			then
				print -Pn "\e]2;${2:q}\a"
				print -Pn "\e]1;${1:q}\a"
			else
				if (( ${+terminfo[fsl]} && ${+terminfo[tsl]} ))
				then
					print -Pn "${terminfo[tsl]}$1${terminfo[fsl]}"
				fi
			fi ;;
	esac
}
try_alias_value () {
	alias_value "$1" || echo "$1"
}
up-line-or-beginning-search () {
	# undefined
	builtin autoload -XU
}
url-quote-magic () {
	# undefined
	builtin autoload -XUz
}
vi_mode_prompt_info () {
	return 1
}
virtualenv_prompt_info () {
	return 1
}
work_in_progress () {
	command git -c log.showSignature=false log -n 1 2> /dev/null | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv} -q -- "--wip--" && echo "WIP!!"
}
y () {
	local tmp="$(mktemp -t "yazi-cwd.XXXXX")" 
	command yazi "$@" --cwd-file="$tmp"
	if cwd="$(<"$tmp")"  && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]
	then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
zle-line-finish () {
	echoti rmkx
}
zle-line-init () {
	echoti smkx
}
zrecompile () {
	setopt localoptions extendedglob noshwordsplit noksharrays
	local opt check quiet zwc files re file pre ret map tmp mesg pats
	tmp=() 
	while getopts ":tqp" opt
	do
		case $opt in
			(t) check=yes  ;;
			(q) quiet=yes  ;;
			(p) pats=yes  ;;
			(*) if [[ -n $pats ]]
				then
					tmp=($tmp $OPTARG) 
				else
					print -u2 zrecompile: bad option: -$OPTARG
					return 1
				fi ;;
		esac
	done
	shift OPTIND-${#tmp}-1
	if [[ -n $check ]]
	then
		ret=1 
	else
		ret=0 
	fi
	if [[ -n $pats ]]
	then
		local end num
		while (( $# ))
		do
			end=$argv[(i)--] 
			if [[ end -le $# ]]
			then
				files=($argv[1,end-1]) 
				shift end
			else
				files=($argv) 
				argv=() 
			fi
			tmp=() 
			map=() 
			OPTIND=1 
			while getopts :MR opt $files
			do
				case $opt in
					([MR]) map=(-$opt)  ;;
					(*) tmp=($tmp $files[OPTIND])  ;;
				esac
			done
			shift OPTIND-1 files
			(( $#files )) || continue
			files=($files[1] ${files[2,-1]:#*(.zwc|~)}) 
			(( $#files )) || continue
			zwc=${files[1]%.zwc}.zwc 
			shift 1 files
			(( $#files )) || files=(${zwc%.zwc}) 
			if [[ -f $zwc ]]
			then
				num=$(zcompile -t $zwc | wc -l) 
				if [[ num-1 -ne $#files ]]
				then
					re=yes 
				else
					re= 
					for file in $files
					do
						if [[ $file -nt $zwc ]]
						then
							re=yes 
							break
						fi
					done
				fi
			else
				re=yes 
			fi
			if [[ -n $re ]]
			then
				if [[ -n $check ]]
				then
					[[ -z $quiet ]] && print $zwc needs re-compilation
					ret=0 
				else
					[[ -z $quiet ]] && print -n "re-compiling ${zwc}: "
					if [[ -z "$quiet" ]] && {
							[[ ! -f $zwc ]] || mv -f $zwc ${zwc}.old
						} && zcompile $map $tmp $zwc $files
					then
						print succeeded
					elif ! {
							{
								[[ ! -f $zwc ]] || mv -f $zwc ${zwc}.old
							} && zcompile $map $tmp $zwc $files 2> /dev/null
						}
					then
						[[ -z $quiet ]] && print "re-compiling ${zwc}: failed"
						ret=1 
					fi
				fi
			fi
		done
		return ret
	fi
	if (( $# ))
	then
		argv=(${^argv}/*.zwc(ND) ${^argv}.zwc(ND) ${(M)argv:#*.zwc}) 
	else
		argv=(${^fpath}/*.zwc(ND) ${^fpath}.zwc(ND) ${(M)fpath:#*.zwc}) 
	fi
	argv=(${^argv%.zwc}.zwc) 
	for zwc
	do
		files=(${(f)"$(zcompile -t $zwc)"}) 
		if [[ $files[1] = *\(mapped\)* ]]
		then
			map=-M 
			mesg='succeeded (old saved)' 
		else
			map=-R 
			mesg=succeeded 
		fi
		if [[ $zwc = */* ]]
		then
			pre=${zwc%/*}/ 
		else
			pre= 
		fi
		if [[ $files[1] != *$ZSH_VERSION ]]
		then
			re=yes 
		else
			re= 
		fi
		files=(${pre}${^files[2,-1]:#/*} ${(M)files[2,-1]:#/*}) 
		[[ -z $re ]] && for file in $files
		do
			if [[ $file -nt $zwc ]]
			then
				re=yes 
				break
			fi
		done
		if [[ -n $re ]]
		then
			if [[ -n $check ]]
			then
				[[ -z $quiet ]] && print $zwc needs re-compilation
				ret=0 
			else
				[[ -z $quiet ]] && print -n "re-compiling ${zwc}: "
				tmp=(${^files}(N)) 
				if [[ $#tmp -ne $#files ]]
				then
					[[ -z $quiet ]] && print 'failed (missing files)'
					ret=1 
				else
					if [[ -z "$quiet" ]] && mv -f $zwc ${zwc}.old && zcompile $map $zwc $files
					then
						print $mesg
					elif ! {
							mv -f $zwc ${zwc}.old && zcompile $map $zwc $files 2> /dev/null
						}
					then
						[[ -z $quiet ]] && print "re-compiling ${zwc}: failed"
						ret=1 
					fi
				fi
			fi
		fi
	done
	return ret
}
zsh-z_plugin_unload () {
	emulate -L zsh
	add-zsh-hook -D precmd _zshz_precmd
	add-zsh-hook -d chpwd _zshz_chpwd
	local x
	for x in ${=ZSHZ[FUNCTIONS]}
	do
		(( ${+functions[$x]} )) && unfunction $x
	done
	unset ZSHZ
	fpath=("${(@)fpath:#${0:A:h}}") 
	(( ${+aliases[${ZSHZ_CMD:-${_Z_CMD:-z}}]} )) && unalias ${ZSHZ_CMD:-${_Z_CMD:-z}}
	unfunction $0
}
zsh_stats () {
	fc -l 1 | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' | grep -v "./" | sort -nr | head -n 20 | column -c3 -s " " -t | nl
}
zshz () {
	setopt LOCAL_OPTIONS NO_KSH_ARRAYS NO_SH_WORD_SPLIT EXTENDED_GLOB UNSET
	(( ZSHZ_DEBUG )) && setopt LOCAL_OPTIONS WARN_CREATE_GLOBAL
	local REPLY
	local -a lines
	local custom_datafile="${ZSHZ_DATA:-$_Z_DATA}" 
	if [[ -n ${custom_datafile} && ${custom_datafile} != */* ]]
	then
		print "ERROR: You configured a custom Zsh-z datafile (${custom_datafile}), but have not specified its directory." >&2
		exit
	fi
	local datafile=${${custom_datafile:-$HOME/.z}:A} 
	if [[ -d $datafile ]]
	then
		print "ERROR: Zsh-z's datafile (${datafile}) is a directory." >&2
		exit
	fi
	[[ -f $datafile ]] || {
		mkdir -p "${datafile:h}" && touch "$datafile"
	}
	[[ -z ${ZSHZ_OWNER:-${_Z_OWNER}} && -f $datafile && ! -O $datafile ]] && return
	lines=(${(f)"$(< $datafile)"}) 
	lines=(${(M)lines:#/*\|[[:digit:]]##[.,]#[[:digit:]]#\|[[:digit:]]##}) 
	_zshz_add_or_remove_path () {
		local action=${1} 
		shift
		if [[ $action == '--add' ]]
		then
			[[ $* == $HOME ]] && return
			local exclude
			for exclude in ${(@)ZSHZ_EXCLUDE_DIRS:-${(@)_Z_EXCLUDE_DIRS}}
			do
				case $* in
					(${exclude} | ${exclude}/*) return ;;
				esac
			done
		fi
		local tempfile="${datafile}.${RANDOM}" 
		if (( ZSHZ[USE_FLOCK] ))
		then
			local lockfd
			zsystem flock -f lockfd "$datafile" 2> /dev/null || return
		fi
		integer tmpfd
		case $action in
			(--add) exec {tmpfd}>| "$tempfile"
				_zshz_update_datafile $tmpfd "$*"
				local ret=$?  ;;
			(--remove) local xdir
				if (( ${ZSHZ_NO_RESOLVE_SYMLINKS:-${_Z_NO_RESOLVE_SYMLINKS}} ))
				then
					[[ -d ${${*:-${PWD}}:a} ]] && xdir=${${*:-${PWD}}:a} 
				else
					[[ -d ${${*:-${PWD}}:A} ]] && xdir=${${*:-${PWD}}:a} 
				fi
				local -a lines_to_keep
				if (( ${+opts[-R]} ))
				then
					if [[ $xdir == '/' ]] && ! read -q "?Delete entire Zsh-z database? "
					then
						print && return 1
					fi
					lines_to_keep=(${lines:#${xdir}\|*}) 
					lines_to_keep=(${lines_to_keep:#${xdir%/}/**}) 
				else
					lines_to_keep=(${lines:#${xdir}\|*}) 
				fi
				if [[ $lines != "$lines_to_keep" ]]
				then
					lines=($lines_to_keep) 
				else
					return 1
				fi
				exec {tmpfd}>| "$tempfile"
				print -u $tmpfd -l -- $lines
				local ret=$?  ;;
		esac
		if (( tmpfd != 0 ))
		then
			exec {tmpfd}>&-
		fi
		if (( ret != 0 ))
		then
			${ZSHZ[RM]} -f "$tempfile"
			return $ret
		fi
		local owner
		owner=${ZSHZ_OWNER:-${_Z_OWNER}} 
		if (( ZSHZ[USE_FLOCK] ))
		then
			if [[ -r '/proc/1/cgroup' && "$(< '/proc/1/cgroup')" == *docker* ]]
			then
				print "$(< "$tempfile")" > "$datafile" 2> /dev/null
				${ZSHZ[RM]} -f "$tempfile"
			else
				${ZSHZ[MV]} "$tempfile" "$datafile" 2> /dev/null || ${ZSHZ[RM]} -f "$tempfile"
			fi
			if [[ -n $owner ]]
			then
				${ZSHZ[CHOWN]} ${owner}:"$(id -ng ${owner})" "$datafile"
			fi
		else
			if [[ -n $owner ]]
			then
				${ZSHZ[CHOWN]} "${owner}":"$(id -ng "${owner}")" "$tempfile"
			fi
			${ZSHZ[MV]} -f "$tempfile" "$datafile" 2> /dev/null || ${ZSHZ[RM]} -f "$tempfile"
		fi
		if [[ $action == '--remove' ]]
		then
			ZSHZ[DIRECTORY_REMOVED]=1 
		fi
	}
	_zshz_update_datafile () {
		integer fd=$1 
		local -A rank time
		local add_path=${(q)2} 
		local -a existing_paths
		local now=$EPOCHSECONDS line dir 
		local path_field rank_field time_field count x
		rank[$add_path]=1 
		time[$add_path]=$now 
		for line in $lines
		do
			if [[ ! -d ${line%%\|*} ]]
			then
				for dir in ${(@)ZSHZ_KEEP_DIRS}
				do
					if [[ ${line%%\|*} == ${dir}/* || ${line%%\|*} == $dir || $dir == '/' ]]
					then
						existing_paths+=($line) 
					fi
				done
			else
				existing_paths+=($line) 
			fi
		done
		lines=($existing_paths) 
		for line in $lines
		do
			path_field=${(q)line%%\|*} 
			rank_field=${${line%\|*}#*\|} 
			time_field=${line##*\|} 
			(( rank_field < 1 )) && continue
			if [[ $path_field == $add_path ]]
			then
				rank[$path_field]=$rank_field 
				(( rank[$path_field]++ ))
				time[$path_field]=$now 
			else
				rank[$path_field]=$rank_field 
				time[$path_field]=$time_field 
			fi
			(( count += rank_field ))
		done
		if (( count > ${ZSHZ_MAX_SCORE:-${_Z_MAX_SCORE:-9000}} ))
		then
			for x in ${(k)rank}
			do
				print -u $fd -- "$x|$(( 0.99 * rank[$x] ))|${time[$x]}" || return 1
			done
		else
			for x in ${(k)rank}
			do
				print -u $fd -- "$x|${rank[$x]}|${time[$x]}" || return 1
			done
		fi
	}
	_zshz_legacy_complete () {
		local line path_field path_field_normalized
		1=${1//[[:space:]]/*} 
		for line in $lines
		do
			path_field=${line%%\|*} 
			path_field_normalized=$path_field 
			if (( ZSHZ_TRAILING_SLASH ))
			then
				path_field_normalized=${path_field%/}/ 
			fi
			if [[ $1 == "${1:l}" && ${path_field_normalized:l} == *${~1}* ]]
			then
				print -- $path_field
			elif [[ $path_field_normalized == *${~1}* ]]
			then
				print -- $path_field
			fi
		done
	}
	_zshz_printv () {
		if (( ZSHZ[PRINTV] ))
		then
			builtin print -v REPLY -f %s $@
		else
			builtin print -z $@
			builtin read -rz REPLY
		fi
	}
	_zshz_find_common_root () {
		local -a common_matches
		local x short
		common_matches=(${(@Pk)1}) 
		for x in ${(@)common_matches}
		do
			if [[ -z $short ]] || (( $#x < $#short )) || [[ $x != ${short}/* ]]
			then
				short=$x 
			fi
		done
		[[ $short == '/' ]] && return
		for x in ${(@)common_matches}
		do
			[[ $x != $short* ]] && return
		done
		_zshz_printv -- $short
	}
	_zshz_output () {
		local match_array=$1 match=$2 format=$3 
		local common k x
		local -a descending_list output
		local -A output_matches
		output_matches=(${(Pkv)match_array}) 
		_zshz_find_common_root $match_array
		common=$REPLY 
		case $format in
			(completion) for k in ${(@k)output_matches}
				do
					_zshz_printv -f "%.2f|%s" ${output_matches[$k]} $k
					descending_list+=(${(f)REPLY}) 
					REPLY='' 
				done
				descending_list=(${${(@On)descending_list}#*\|}) 
				print -l $descending_list ;;
			(list) local path_to_display
				for x in ${(k)output_matches}
				do
					if (( ${output_matches[$x]} ))
					then
						path_to_display=$x 
						(( ZSHZ_TILDE )) && path_to_display=${path_to_display/#${HOME}/\~} 
						_zshz_printv -f "%-10d %s\n" ${output_matches[$x]} $path_to_display
						output+=(${(f)REPLY}) 
						REPLY='' 
					fi
				done
				if [[ -n $common ]]
				then
					(( ZSHZ_TILDE )) && common=${common/#${HOME}/\~} 
					(( $#output > 1 )) && printf "%-10s %s\n" 'common:' $common
				fi
				if (( $+opts[-t] ))
				then
					for x in ${(@On)output}
					do
						print -- $x
					done
				elif (( $+opts[-r] ))
				then
					for x in ${(@on)output}
					do
						print -- $x
					done
				else
					for x in ${(@on)output}
					do
						print $x
					done
				fi ;;
			(*) if (( ! ZSHZ_UNCOMMON )) && [[ -n $common ]]
				then
					_zshz_printv -- $common
				else
					_zshz_printv -- ${(P)match}
				fi ;;
		esac
	}
	_zshz_find_matches () {
		setopt LOCAL_OPTIONS NO_EXTENDED_GLOB
		local fnd=$1 method=$2 format=$3 
		local -a existing_paths
		local line dir path_field rank_field time_field rank dx escaped_path_field
		local -A matches imatches
		local best_match ibest_match hi_rank=-9999999999 ihi_rank=-9999999999 
		for line in $lines
		do
			if [[ ! -d ${line%%\|*} ]]
			then
				for dir in ${(@)ZSHZ_KEEP_DIRS}
				do
					if [[ ${line%%\|*} == ${dir}/* || ${line%%\|*} == $dir || $dir == '/' ]]
					then
						existing_paths+=($line) 
					fi
				done
			else
				existing_paths+=($line) 
			fi
		done
		lines=($existing_paths) 
		for line in $lines
		do
			path_field=${line%%\|*} 
			rank_field=${${line%\|*}#*\|} 
			time_field=${line##*\|} 
			case $method in
				(rank) rank=$rank_field  ;;
				(time) (( rank = time_field - EPOCHSECONDS )) ;;
				(*) (( dx = EPOCHSECONDS - time_field ))
					rank=$(( 10000 * rank_field * (3.75/( (0.0001 * dx + 1) + 0.25)) ))  ;;
			esac
			local q=${fnd//[[:space:]]/\*} 
			local path_field_normalized=$path_field 
			if (( ZSHZ_TRAILING_SLASH ))
			then
				path_field_normalized=${path_field%/}/ 
			fi
			if [[ $ZSHZ_CASE == 'smart' && ${1:l} == $1 && ${path_field_normalized:l} == ${~q:l} ]]
			then
				imatches[$path_field]=$rank 
			elif [[ $ZSHZ_CASE != 'ignore' && $path_field_normalized == ${~q} ]]
			then
				matches[$path_field]=$rank 
			elif [[ $ZSHZ_CASE != 'smart' && ${path_field_normalized:l} == ${~q:l} ]]
			then
				imatches[$path_field]=$rank 
			fi
			escaped_path_field=${path_field//'\'/'\\'} 
			escaped_path_field=${escaped_path_field//'`'/'\`'} 
			escaped_path_field=${escaped_path_field//'('/'\('} 
			escaped_path_field=${escaped_path_field//')'/'\)'} 
			escaped_path_field=${escaped_path_field//'['/'\['} 
			escaped_path_field=${escaped_path_field//']'/'\]'} 
			if (( matches[$escaped_path_field] )) && (( matches[$escaped_path_field] > hi_rank ))
			then
				best_match=$path_field 
				hi_rank=${matches[$escaped_path_field]} 
			elif (( imatches[$escaped_path_field] )) && (( imatches[$escaped_path_field] > ihi_rank ))
			then
				ibest_match=$path_field 
				ihi_rank=${imatches[$escaped_path_field]} 
				ZSHZ[CASE_INSENSITIVE]=1 
			fi
		done
		[[ -z $best_match && -z $ibest_match ]] && return 1
		if [[ -n $best_match ]]
		then
			_zshz_output matches best_match $format
		elif [[ -n $ibest_match ]]
		then
			_zshz_output imatches ibest_match $format
		fi
	}
	local -A opts
	zparseopts -E -D -A opts -- -add -complete c e h -help l r R t x
	if [[ $1 == '--' ]]
	then
		shift
	elif [[ -n ${(M)@:#-*} && -z $compstate ]]
	then
		print "Improper option(s) given."
		_zshz_usage
		return 1
	fi
	local opt output_format method='frecency' fnd prefix req 
	for opt in ${(k)opts}
	do
		case $opt in
			(--add) [[ ! -d $* ]] && return 1
				local dir
				if [[ $OSTYPE == (cygwin|msys) && $PWD == '/' && $* != /* ]]
				then
					set -- "/$*"
				fi
				if (( ${ZSHZ_NO_RESOLVE_SYMLINKS:-${_Z_NO_RESOLVE_SYMLINKS}} ))
				then
					dir=${*:a} 
				else
					dir=${*:A} 
				fi
				_zshz_add_or_remove_path --add "$dir"
				return ;;
			(--complete) if [[ -s $datafile && ${ZSHZ_COMPLETION:-frecent} == 'legacy' ]]
				then
					_zshz_legacy_complete "$1"
					return
				fi
				output_format='completion'  ;;
			(-c) [[ $* == ${PWD}/* || $PWD == '/' ]] || prefix="$PWD "  ;;
			(-h | --help) _zshz_usage
				return ;;
			(-l) output_format='list'  ;;
			(-r) method='rank'  ;;
			(-t) method='time'  ;;
			(-x) if [[ $OSTYPE == (cygwin|msys) && $PWD == '/' && $* != /* ]]
				then
					set -- "/$*"
				fi
				_zshz_add_or_remove_path --remove $*
				return ;;
		esac
	done
	req="$*" 
	fnd="$prefix$*" 
	[[ -n $fnd && $fnd != "$PWD " ]] || {
		[[ $output_format != 'completion' ]] && output_format='list' 
	}
	zshz_cd () {
		setopt LOCAL_OPTIONS NO_WARN_CREATE_GLOBAL
		if [[ -z $ZSHZ_CD ]]
		then
			builtin cd "$*"
		else
			${=ZSHZ_CD} "$*"
		fi
	}
	_zshz_echo () {
		if (( ZSHZ_ECHO ))
		then
			if (( ZSHZ_TILDE ))
			then
				print ${PWD/#${HOME}/\~}
			else
				print $PWD
			fi
		fi
	}
	if [[ ${@: -1} == /* ]] && (( ! $+opts[-e] && ! $+opts[-l] ))
	then
		[[ -d ${@: -1} ]] && zshz_cd ${@: -1} && _zshz_echo && return
	fi
	if [[ ! -z ${(tP)opts[-c]} ]]
	then
		_zshz_find_matches "$fnd*" $method $output_format
	else
		_zshz_find_matches "*$fnd*" $method $output_format
	fi
	local ret2=$? 
	local cd
	cd=$REPLY 
	if (( ZSHZ_UNCOMMON )) && [[ -n $cd ]]
	then
		if [[ -n $cd ]]
		then
			local q=${fnd//[[:space:]]/\*} 
			q=${q%/} 
			if (( ! ZSHZ[CASE_INSENSITIVE] ))
			then
				local q_chars=$(( ${#cd} - ${#${cd//${~q}/}} )) 
				until (( ( ${#cd:h} - ${#${${cd:h}//${~q}/}} ) != q_chars ))
				do
					cd=${cd:h} 
				done
			else
				local q_chars=$(( ${#cd} - ${#${${cd:l}//${~${q:l}}/}} )) 
				until (( ( ${#cd:h} - ${#${${${cd:h}:l}//${~${q:l}}/}} ) != q_chars ))
				do
					cd=${cd:h} 
				done
			fi
			ZSHZ[CASE_INSENSITIVE]=0 
		fi
	fi
	if (( ret2 == 0 )) && [[ -n $cd ]]
	then
		if (( $+opts[-e] ))
		then
			(( ZSHZ_TILDE )) && cd=${cd/#${HOME}/\~} 
			print -- "$cd"
		else
			[[ -d $cd ]] && zshz_cd "$cd" && _zshz_echo
		fi
	else
		if ! (( $+opts[-e] || $+opts[-l] )) && [[ -d $req ]]
		then
			zshz_cd "$req" && _zshz_echo
		else
			return $ret2
		fi
	fi
}

# setopts 20
setopt alwaystoend
setopt autocd
setopt autopushd
setopt completeinword
setopt extendedhistory
setopt noflowcontrol
setopt nohashdirs
setopt histexpiredupsfirst
setopt histfcntllock
setopt histignoredups
setopt histignorespace
setopt histverify
setopt incappendhistory
setopt interactivecomments
setopt login
setopt longlistjobs
setopt promptsubst
setopt pushdignoredups
setopt pushdminus
setopt sharehistory

# aliases 271
alias -- -='cd -'
alias -g ...=../..
alias -g ....=../../..
alias -g .....=../../../..
alias -g ......=../../../../..
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'
alias -g G='| grep'
alias -g UUID='$(uuidgen | tr -d \n)'
alias _='sudo '
alias argon='ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes -o IdentitiesOnly=yes -o IdentityAgent=none zjgilliam@argon.hpc.uiowa.edu'
alias att='tmux attach'
alias attach='tmux attach'
alias bc='bc -ql'
alias cls=clear
alias cmat='cmatrix -C magenta'
alias cnlss='sudo mount -t cifs //itf-rs-store24.hpc.uiowa.edu/vosslabhpc /mnt/lss -o credentials=/etc/lss-creds,uid=$(id -u),gid=$(id -g),file_mode=0644,dir_mode=0755,noperm'
alias cnrdss='sudo mount -t cifs //rdss.iowa.uiowa.edu/rdss_mwvoss /mnt/rdss  -o vers=3.1.1,sec=krb5,cruid=1000,uid=1000,gid=100'
alias cp='cp -iv'
alias current_branch=$'\n    print -Pu2 "%F{yellow}[oh-my-zsh] \'%F{red}current_branch%F{yellow}\' is deprecated, using \'%F{green}git_current_branch%F{yellow}\' instead.%f"\n    git_current_branch'
alias dev='cd /mnt/work/Projects/'
alias dk=docker
alias dkd='docker compose down'
alias dku='docker compose up -d'
alias dots='cd ~/NixOS/'
alias egrep='grep -E'
alias fgrep='grep -F'
alias find-store-path='function { nix-shell -p $1 --command "nix eval -f \"<nixpkgs>\" --raw $1" }'
alias g=git
alias ga='git add'
alias gaa='git add --all'
alias gam='git am'
alias gama='git am --abort'
alias gamc='git am --continue'
alias games='cd /mnt/games/'
alias gams='git am --skip'
alias gamscp='git am --show-current-patch'
alias gap='git apply'
alias gapa='git add --patch'
alias gapt='git apply --3way'
alias gau='git add --update'
alias gav='git add --verbose'
alias gb='git branch'
alias gbD='git branch --delete --force'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbg='LANG=C git branch -vv | grep ": gone\]"'
alias gbgD='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -D'
alias gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -d'
alias gbl='git blame -w'
alias gbm='git branch --move'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsn='git bisect new'
alias gbso='git bisect old'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gc='git commit --verbose'
alias gc!='git commit --verbose --amend'
alias gcB='git checkout -B'
alias gca='git commit --verbose --all'
alias gca!='git commit --verbose --all --amend'
alias gcam='git commit --all --message'
alias gcan!='git commit --verbose --all --no-edit --amend'
alias gcann!='git commit --verbose --all --date=now --no-edit --amend'
alias gcans!='git commit --verbose --all --signoff --no-edit --amend'
alias gcas='git commit --all --signoff'
alias gcasm='git commit --all --signoff --message'
alias gcb='git checkout -b'
alias gcd='git checkout $(git_develop_branch)'
alias gcf='git config --list'
alias gcfu='git commit --fixup'
alias gcl='git clone --recurse-submodules'
alias gclean='git clean --interactive -d'
alias gclf='git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules'
alias gcm='git checkout $(git_main_branch)'
alias gcmsg='git commit --message'
alias gcn='git commit --verbose --no-edit'
alias gcn!='git commit --verbose --no-edit --amend'
alias gco='git checkout'
alias gcor='git checkout --recurse-submodules'
alias gcount='git shortlog --summary --numbered'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gcs='git commit --gpg-sign'
alias gcsm='git commit --signoff --message'
alias gcss='git commit --gpg-sign --signoff'
alias gcssm='git commit --gpg-sign --signoff --message'
alias gd='git diff'
alias gdca='git diff --cached'
alias gdct='git describe --tags $(git rev-list --tags --max-count=1)'
alias gdcw='git diff --cached --word-diff'
alias gds='git diff --staged'
alias gdt='git diff-tree --no-commit-id --name-only -r'
alias gdup='git diff @{upstream}'
alias gdw='git diff --word-diff'
alias gf='git fetch'
alias gfa='git fetch --all --tags --prune --jobs=10'
alias gfg='git ls-files | grep'
alias gfo='git fetch origin'
alias gg='git gui citool'
alias gga='git gui citool --amend'
alias ggpull='git pull origin "$(git_current_branch)"'
alias ggpur=ggu
alias ggpush='git push origin "$(git_current_branch)"'
alias ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
alias ghh='git help'
alias gignore='git update-index --assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias git-svn-dcommit-push='git svn dcommit && git push github $(git_main_branch):svntrunk'
alias gk='\gitk --all --branches &!'
alias gke='\gitk --all $(git log --walk-reflogs --pretty=%h) &!'
alias gl='git pull'
alias glg='git log --stat'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glgm='git log --graph --max-count=10'
alias glgp='git log --stat --patch'
alias glo='git log --oneline --decorate'
alias glod='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
alias glods='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
alias glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
alias glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
alias glp=_git_log_prettily
alias gluc='git pull upstream $(git_current_branch)'
alias glum='git pull upstream $(git_main_branch)'
alias gm='git merge'
alias gma='git merge --abort'
alias gmc='git merge --continue'
alias gmff='git merge --ff-only'
alias gmom='git merge origin/$(git_main_branch)'
alias gms='git merge --squash'
alias gmtl='git mergetool --no-prompt'
alias gmtlvim='git mergetool --no-prompt --tool=vimdiff'
alias gmum='git merge upstream/$(git_main_branch)'
alias gp='git push'
alias gpd='git push --dry-run'
alias gpf='git push --force-with-lease --force-if-includes'
alias gpf!='git push --force'
alias gpoat='git push origin --all && git push origin --tags'
alias gpod='git push origin --delete'
alias gpr='git pull --rebase'
alias gpra='git pull --rebase --autostash'
alias gprav='git pull --rebase --autostash -v'
alias gpristine='git reset --hard && git clean --force -dfx'
alias gprom='git pull --rebase origin $(git_main_branch)'
alias gpromi='git pull --rebase=interactive origin $(git_main_branch)'
alias gprum='git pull --rebase upstream $(git_main_branch)'
alias gprumi='git pull --rebase=interactive upstream $(git_main_branch)'
alias gprv='git pull --rebase -v'
alias gpsup='git push --set-upstream origin $(git_current_branch)'
alias gpsupf='git push --set-upstream origin $(git_current_branch) --force-with-lease --force-if-includes'
alias gpu='git push upstream'
alias gpv='git push --verbose'
alias gr='git remote'
alias gra='git remote add'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbd='git rebase $(git_develop_branch)'
alias grbi='git rebase --interactive'
alias grbm='git rebase $(git_main_branch)'
alias grbo='git rebase --onto'
alias grbom='git rebase origin/$(git_main_branch)'
alias grbs='git rebase --skip'
alias grbum='git rebase upstream/$(git_main_branch)'
alias grep='grep --color=always'
alias grev='git revert'
alias greva='git revert --abort'
alias grevc='git revert --continue'
alias grf='git reflog'
alias grh='git reset'
alias grhh='git reset --hard'
alias grhk='git reset --keep'
alias grhs='git reset --soft'
alias grm='git rm'
alias grmc='git rm --cached'
alias grmv='git remote rename'
alias groh='git reset origin/$(git_current_branch) --hard'
alias grrm='git remote remove'
alias grs='git restore'
alias grset='git remote set-url'
alias grss='git restore --source'
alias grst='git restore --staged'
alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'
alias gru='git reset --'
alias grup='git remote update'
alias grv='git remote --verbose'
alias gsb='git status --short --branch'
alias gsd='git svn dcommit'
alias gsh='git show'
alias gsi='git submodule init'
alias gsps='git show --pretty=short --show-signature'
alias gsr='git svn rebase'
alias gss='git status --short'
alias gst='git status'
alias gsta='git stash push'
alias gstaa='git stash apply'
alias gstall='git stash --all'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --patch'
alias gstu='gsta --include-untracked'
alias gsu='git submodule update'
alias gsw='git switch'
alias gswc='git switch --create'
alias gswd='git switch $(git_develop_branch)'
alias gswm='git switch $(git_main_branch)'
alias gta='git tag --annotate'
alias gtl='gtl(){ git tag --sort=-v:refname -n --list "${1}*" }; noglob gtl'
alias gts='git tag --sign'
alias gtv='git tag | sort -V'
alias gunignore='git update-index --no-assume-unchanged'
alias gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'
alias gwch='git log --patch --abbrev-commit --pretty=medium --raw'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
alias gwipe='git reset --hard && git clean --force -df'
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtls='git worktree list'
alias gwtmv='git worktree move'
alias gwtrm='git worktree remove'
alias history=omz_history
alias l='/nix/store/qp35x1axyz19dyz5vkxw8qyk3ibfbnyl-eza-0.23.4/bin/eza -lh  --icons=auto'
alias la='ls -lAh'
alias ld='/nix/store/qp35x1axyz19dyz5vkxw8qyk3ibfbnyl-eza-0.23.4/bin/eza -lhD --icons=auto'
alias lg=lazygit
alias list-gens='sudo nix-env --list-generations --profile /nix/var/nix/profiles/system/'
alias ll='/nix/store/qp35x1axyz19dyz5vkxw8qyk3ibfbnyl-eza-0.23.4/bin/eza -lha --icons=auto --sort=name --group-directories-first'
alias ls='/nix/store/qp35x1axyz19dyz5vkxw8qyk3ibfbnyl-eza-0.23.4/bin/eza -1   --icons=auto'
alias lsa='ls -lah'
alias md='mkdir -p'
alias media='cd /mnt/work/media/'
alias mkd='mkdir -pv'
alias mv='mv -iv'
alias nf=/nix/store/3vaqj31nlc24c7bdrq8z2568195s8xz1-microfetch-0.4.13/bin/microfetch
alias nv=nvim
alias pokemon='pokego --random 1-8 --no-title'
alias proj='cd /mnt/work/Projects/'
alias projects='cd /mnt/work/Projects/'
alias rd=rmdir
alias rebuild=/nix/store/dmarad4kmyk43r2bb50lypn3gllzl0jl-rebuild.sh
alias rm='rm -vI'
alias run-help=man
alias sysup='sudo nixos-rebuild switch --flake ~/NixOS#Default --upgrade-all --show-trace'
alias tml='tmux list-sessions'
alias tp=/nix/store/v6wgsxg2dfn8ir8hb4r7k9gsfamq1qdx-trash-cli-0.24.5.26/bin/trash-put
alias tpr=/nix/store/v6wgsxg2dfn8ir8hb4r7k9gsfamq1qdx-trash-cli-0.24.5.26/bin/trash-restore
alias tree='/nix/store/qp35x1axyz19dyz5vkxw8qyk3ibfbnyl-eza-0.23.4/bin/eza --icons=auto --tree'
alias update-input='nix flake update $@'
alias vc='code --disable-gpu'
alias vosslnx='ssh -o PubkeyAuthentication=no -o PasswordAuthentication=yes -o IdentitiesOnly=yes -o IdentityAgent=none zjgilliam@vosslab.psychology.uiowa.edu'
alias which-command=whence
alias work='cd /home/zak/work/'
alias z='zshz 2>&1'

# exports 151
export APPLICATION_INSIGHTS_NO_STATSBEAT=true
export BROWSER=brave
export CHROME_DESKTOP=code.desktop
export CLUTTER_BACKEND=wayland
export CODEX_HOME=/home/zak/work/hbc/boost/act/.codex
export CODEX_INTERNAL_ORIGINATOR_OVERRIDE=codex_vscode
export COLORTERM=truecolor
export DBUS_SESSION_BUS_ADDRESS='unix:path=/run/user/1000/bus'
export DEBUG=release
export DESKTOP_SESSION=hyprland
export DIRENV_WARN_TIMEOUT=60s
export DISPLAY=:1
export EDITOR=nvim
export EGL_PLATFORM=wayland
export ELECTRON_NO_ATTACH_CONSOLE=1
export ELECTRON_OZONE_PLATFORM_HINT=auto
export ELECTRON_RUN_AS_NODE=1
export FC_FONTATIONS=1
export FZF_DEFAULT_OPTS=$' --color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \n--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796'
export GBM_BACKEND=nvidia-drm
export GDK_BACKEND=wayland
export GDK_PIXBUF_MODULE_FILE=/nix/store/6r0krhrml6hz987s40kbqczq5923i7ix-librsvg-2.61.3/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
export GIO_EXTRA_MODULES=/nix/store/35546s9rph83k81mmagfssbr2ml0ai12-dconf-0.49.0-lib/lib/gio/modules:/nix/store/bp8jnslpyzdhvjspa8slvrny1pd6ayay-gvfs-1.58.1/lib/gio/modules
export GPG_TTY=/dev/pts/3
export GTK2_RC_FILES=/home/zak/.gtkrc-2.0
export GTK_A11Y=none
export GTK_PATH=/home/zak/.nix-profile/lib/gtk-2.0:/home/zak/.nix-profile/lib/gtk-3.0:/home/zak/.nix-profile/lib/gtk-4.0:/nix/profile/lib/gtk-2.0:/nix/profile/lib/gtk-3.0:/nix/profile/lib/gtk-4.0:/home/zak/.local/state/nix/profile/lib/gtk-2.0:/home/zak/.local/state/nix/profile/lib/gtk-3.0:/home/zak/.local/state/nix/profile/lib/gtk-4.0:/etc/profiles/per-user/zak/lib/gtk-2.0:/etc/profiles/per-user/zak/lib/gtk-3.0:/etc/profiles/per-user/zak/lib/gtk-4.0:/nix/var/nix/profiles/default/lib/gtk-2.0:/nix/var/nix/profiles/default/lib/gtk-3.0:/nix/var/nix/profiles/default/lib/gtk-4.0:/run/current-system/sw/lib/gtk-2.0:/run/current-system/sw/lib/gtk-3.0:/run/current-system/sw/lib/gtk-4.0
export HL_INITIAL_WORKSPACE_TOKEN=40133c40-62c2-4376-989b-5145918a3bb4
export HOME=/home/zak
export HYPRLAND_CMD='/etc/profiles/per-user/zak/bin/Hyprland --watchdog-fd 4'
export HYPRLAND_INSTANCE_SIGNATURE=4b07770b9ef1cceb2e6f56d33538aaffb9186b9c_1773134933_2056956019
export INFOPATH=/home/zak/.nix-profile/info:/home/zak/.nix-profile/share/info:/nix/profile/info:/nix/profile/share/info:/home/zak/.local/state/nix/profile/info:/home/zak/.local/state/nix/profile/share/info:/etc/profiles/per-user/zak/info:/etc/profiles/per-user/zak/share/info:/nix/var/nix/profiles/default/info:/nix/var/nix/profiles/default/share/info:/run/current-system/sw/info:/run/current-system/sw/share/info
export KITTY_INSTALLATION_DIR=/nix/store/7pjcjlyx7iafpgi606rczchcl980xdn6-kitty-0.45.0/lib/kitty
export KITTY_PID=9900
export KITTY_PUBLIC_KEY='1:dFyGee8OQ%g=_5kIa$^Kd{ySR9Pf@18h^q4Tj+-Y'
export KITTY_SHELL_INTEGRATION=no-rc
export KITTY_WINDOW_ID=1
export LANG=en_US.UTF-8
export LC_ADDRESS=en_US.UTF-8
export LC_IDENTIFICATION=en_US.UTF-8
export LC_MEASUREMENT=en_US.UTF-8
export LC_MONETARY=en_US.UTF-8
export LC_NAME=en_US.UTF-8
export LC_NUMERIC=en_US.UTF-8
export LC_PAPER=en_US.UTF-8
export LC_TELEPHONE=en_US.UTF-8
export LC_TIME=en_US.UTF-8
export LD_LIBRARY_PATH=/nix/store/zdsinlc551yvssz9vs4c0plhr1azzf22-libdbusmenu-glib-16.04.0/lib
export LESS=-R
export LESSKEYIN_SYSTEM=/nix/store/afnfwm9w6g4s4c4glz8iz6p8wjh54mzv-lessconfig
export LIBEXEC_PATH=/home/zak/.nix-profile/libexec:/nix/profile/libexec:/home/zak/.local/state/nix/profile/libexec:/etc/profiles/per-user/zak/libexec:/nix/var/nix/profiles/default/libexec:/run/current-system/sw/libexec
export LIBVA_DRIVER_NAME=nvidia
export LOCALE_ARCHIVE=/run/current-system/sw/lib/locale/locale-archive
export LOCALE_ARCHIVE_2_27=/nix/store/vnc4174wvr9mjncdj95k7kbgwxxzphwp-glibc-locales-2.42-51/lib/locale/locale-archive
export LOGNAME=zak
export LSCOLORS=Gxfxcxdxbxegedabagacad
export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=00:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.7z=01;31:*.ace=01;31:*.alz=01;31:*.apk=01;31:*.arc=01;31:*.arj=01;31:*.bz=01;31:*.bz2=01;31:*.cab=01;31:*.cpio=01;31:*.crate=01;31:*.deb=01;31:*.drpm=01;31:*.dwm=01;31:*.dz=01;31:*.ear=01;31:*.egg=01;31:*.esd=01;31:*.gz=01;31:*.jar=01;31:*.lha=01;31:*.lrz=01;31:*.lz=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.lzo=01;31:*.pyz=01;31:*.rar=01;31:*.rpm=01;31:*.rz=01;31:*.sar=01;31:*.swm=01;31:*.t7z=01;31:*.tar=01;31:*.taz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tgz=01;31:*.tlz=01;31:*.txz=01;31:*.tz=01;31:*.tzo=01;31:*.tzst=01;31:*.udeb=01;31:*.war=01;31:*.whl=01;31:*.wim=01;31:*.xz=01;31:*.z=01;31:*.zip=01;31:*.zoo=01;31:*.zst=01;31:*.avif=01;35:*.jpg=01;35:*.jpeg=01;35:*.jxl=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:*~=00;90:*#=00;90:*.bak=00;90:*.crdownload=00;90:*.dpkg-dist=00;90:*.dpkg-new=00;90:*.dpkg-old=00;90:*.dpkg-tmp=00;90:*.old=00;90:*.orig=00;90:*.part=00;90:*.rej=00;90:*.rpmnew=00;90:*.rpmorig=00;90:*.rpmsave=00;90:*.swp=00;90:*.tmp=00;90:*.ucf-dist=00;90:*.ucf-new=00;90:*.ucf-old=00;90:'
export MANGOHUD=1
export MANGOHUD_DLSYM=1
export MOZ_ENABLE_WAYLAND=1
export NH_FLAKE=/home/zak/NixOS
export NIXOS_OZONE_WL=1
export NIXOS_XDG_OPEN_USE_PORTAL=1
export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_CONFIG=/etc/nix/nixpkgs-config.nix
export NIX_LD=/run/current-system/sw/share/nix-ld/lib/ld.so
export NIX_LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib
export NIX_PATH='nixpkgs=flake:nixpkgs:/nix/var/nix/profiles/per-user/root/channels'
export NIX_PROFILES='/run/current-system/sw /nix/var/nix/profiles/default /etc/profiles/per-user/zak /home/zak/.local/state/nix/profile /nix/profile /home/zak/.nix-profile'
export NIX_USER_PROFILE_DIR=/nix/var/nix/profiles/per-user/zak
export NIX_XDG_DESKTOP_PORTAL_DIR=/etc/profiles/per-user/zak/share/xdg-desktop-portal/portals
export NO_AT_BRIDGE=1
export NVD_BACKEND=direct
export OZONE_PLATFORM=wayland
export P9K_TTY=old
export PAGER=less
export QML2_IMPORT_PATH=/etc/profiles/per-user/zak/lib/qt-5.15.18/qml:/etc/profiles/per-user/zak/lib/qt-6/qml
export QTWEBKIT_PLUGIN_PATH=/home/zak/.nix-profile/lib/mozilla/plugins/:/nix/profile/lib/mozilla/plugins/:/home/zak/.local/state/nix/profile/lib/mozilla/plugins/:/etc/profiles/per-user/zak/lib/mozilla/plugins/:/nix/var/nix/profiles/default/lib/mozilla/plugins/:/run/current-system/sw/lib/mozilla/plugins/
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_PLUGIN_PATH=/etc/profiles/per-user/zak/lib/qt-5.15.18/plugins:/etc/profiles/per-user/zak/lib/qt-6/plugins
export QT_QPA_PLATFORM='wayland;xcb'
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=kvantum
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export RUST_LOG=warn
export SDL_VIDEODRIVER=wayland
export SHELL=/run/current-system/sw/bin/zsh
export SSH_ASKPASS=/nix/store/c3n631sfslh800d67z79q3flji28n334-x11-ssh-askpass-1.2.4.1/libexec/x11-ssh-askpass
export SSH_AUTH_SOCK=/run/user/1000/gnupg/S.gpg-agent.ssh
export STARSHIP_CONFIG=/home/zak/.config/starship.toml
export STARSHIP_SESSION_KEY=1935834622310617
export STARSHIP_SHELL=zsh
export TERM=screen-256color
export TERMINAL=kitty
export TERMINFO=/nix/store/7pjcjlyx7iafpgi606rczchcl980xdn6-kitty-0.45.0/lib/kitty/terminfo
export TERMINFO_DIRS=/home/zak/.nix-profile/share/terminfo:/nix/profile/share/terminfo:/home/zak/.local/state/nix/profile/share/terminfo:/etc/profiles/per-user/zak/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/run/current-system/sw/share/terminfo
export TERM_PROGRAM=tmux
export TERM_PROGRAM_VERSION=3.6a
export TMUX=/run/user/1000/tmux-1000/default,9915,4
export TMUX_PANE=%31
export TMUX_TMPDIR=/run/user/1000
export TZDIR=/etc/zoneinfo
export USER=zak
export VDPAU_DRIVER=nvidia
export VSCODE_CLI=1
export VSCODE_CODE_CACHE_PATH=/home/zak/.config/Code/CachedData/072586267e68ece9a47aa43f8c108e0dcbf44622
export VSCODE_CRASH_REPORTER_PROCESS_TYPE=extensionHost
export VSCODE_CWD=/home/zak
export VSCODE_ESM_ENTRYPOINT=vs/workbench/api/node/extensionHostProcess
export VSCODE_HANDLES_UNCAUGHT_ERRORS=true
export VSCODE_IPC_HOOK=/run/user/1000/vscode-d3b8a5de-1.10-main.sock
export VSCODE_NLS_CONFIG='{"userLocale":"en-us","osLocale":"en-us","resolvedLanguage":"en","defaultMessagesFile":"/nix/store/dddabh2n29lqnfnb637ply1xidqxi8n4-vscode-1.109.5/lib/vscode/resources/app/out/nls.messages.json","locale":"en-us","availableLanguages":{}}'
export VSCODE_PID=43828
export WAYLAND_DISPLAY=wayland-1
export WLR_DRM_NO_ATOMIC=0
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1
export XCURSOR_PATH=/etc/profiles/per-user/zak/share/icons:/home/zak/.icons:/home/zak/.local/share/icons:/home/zak/.nix-profile/share/icons:/home/zak/.nix-profile/share/pixmaps:/nix/profile/share/icons:/nix/profile/share/pixmaps:/home/zak/.local/state/nix/profile/share/icons:/home/zak/.local/state/nix/profile/share/pixmaps:/etc/profiles/per-user/zak/share/icons:/etc/profiles/per-user/zak/share/pixmaps:/nix/var/nix/profiles/default/share/icons:/nix/var/nix/profiles/default/share/pixmaps:/run/current-system/sw/share/icons:/run/current-system/sw/share/pixmaps
export XCURSOR_SIZE=24
export XCURSOR_THEME=Bibata-Modern-Classic
export XDG_BACKEND=wayland
export XDG_BIN_HOME=/home/zak/.local/bin
export XDG_CACHE_HOME=/home/zak/.cache
export XDG_CONFIG_DIRS=/etc/xdg:/home/zak/.nix-profile/etc/xdg:/nix/profile/etc/xdg:/home/zak/.local/state/nix/profile/etc/xdg:/etc/profiles/per-user/zak/etc/xdg:/nix/var/nix/profiles/default/etc/xdg:/run/current-system/sw/etc/xdg
export XDG_CONFIG_HOME=/home/zak/.config
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_DATA_DIRS=/nix/store/dddabh2n29lqnfnb637ply1xidqxi8n4-vscode-1.109.5/share:/nix/store/v5s2sldwj887dm1cn928fzrpnb84pkf8-gsettings-desktop-schemas-49.1/share/gsettings-schemas/gsettings-desktop-schemas-49.1:/nix/store/q43d6pbb9qxyhj6hq4id5mdg6gfrz6gv-gtk+3-3.24.51/share/gsettings-schemas/gtk+3-3.24.51:/nix/store/g2m1q0sxbxmh0qzy8akispmcvpnvji8n-desktops/share:/home/zak/.nix-profile/share:/nix/profile/share:/home/zak/.local/state/nix/profile/share:/etc/profiles/per-user/zak/share:/nix/var/nix/profiles/default/share:/run/current-system/sw/share
export XDG_DATA_HOME=/home/zak/.local/share
export XDG_RUNTIME_DIR=/run/user/1000
export XDG_SEAT=seat0
export XDG_SEAT_PATH=/org/freedesktop/DisplayManager/Seat0
export XDG_SESSION_CLASS=user
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_ID=3
export XDG_SESSION_PATH=/org/freedesktop/DisplayManager/Session1
export XDG_SESSION_TYPE=wayland
export XDG_STATE_HOME=/home/zak/.local/state
export XDG_VTNR=1
export XMONAD_CACHE_DIR=/home/zak/.cache/xmonad
export XMONAD_CONFIG_DIR=/home/zak/.config/xmonad
export XMONAD_DATA_DIR=/home/zak/.local/share/xmonad
export ZDOTDIR=/home/zak/.config/zsh
export _JAVA_AWT_WM_NONREPARENTING=1
export _P9K_SSH_TTY=''
export _P9K_TTY=/dev/pts/3
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __GL_GSYNC_ALLOWED=1
export __HM_SESS_VARS_SOURCED=1
export __HM_ZSH_SESS_VARS_SOURCED=1
export __NIXOS_SET_ENVIRONMENT_DONE=1
export templates=/nix/store/6hr9z1v58mpwymxk0r6c0qg56z8nk5kf-source/dev-shells
