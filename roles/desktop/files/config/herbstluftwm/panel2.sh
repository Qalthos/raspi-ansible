#!/bin/bash
# vim: set fileencoding=utf-8 ts=4 sts=4 sw=4 tw=80 expandtab :
# Florian Bruhin <me@the-compiler.org>

monitor=$1
geometry=( $(herbstclient monitor_rect $monitor) )
x=${geometry[0]}
y=${geometry[1]}
width=${geometry[2]}

[[ $0 == /* ]] && script="$0" || script="${PWD}/${0#./}"
panelfolder=${script%/*}
trap 'herbstclient emit_hook quit_panel' TERM
herbstclient pad $monitor 16
herbstclient emit_hook quit_panel

dzen_fg="#ffffff"
dzen_bg="#1c1c1c"
normal_fg=""
normal_bg=
viewed_fg="#000000"
viewed_bg="#afdf87"
other_fg="#87dffa"
other_bg=
urgent_fg=
urgent_bg="#df8787"
used_fg="#afdf87"
used_bg=

CONKY_PIPE=/tmp/conky-pipe
if [ $monitor == 0 ]; then
    if [ ! -p $CONKY_PIPE ]; then
        if [ -e $CONKY_PIPE ]; then
            rm -r $CONKY_PIPE
        fi
        mkfifo -m 600 $CONKY_PIPE
    fi
    conky -c "$panelfolder/conkyrc" > $CONKY_PIPE &
    pids+=($!)
fi

herbstclient --idle 2>/dev/null | {
    tags=( $(herbstclient tag_status) )
    windowtitle=""
    while true; do
        for tag in "${tags[@]}" ; do
            case ${tag:0:1} in
                '-') cstart="^fg($other_fg)^bg($other_bg)" ;;
                '#') cstart="^fg($viewed_fg)^bg($viewed_bg)" ;;
                '+') cstart="^fg($viewed_fg)^bg($viewed_bg)" ;;
                ':') cstart="^fg($used_fg)^bg($used_bg)"     ;;
                '!') cstart="^fg($urgent_fg)^bg($urgent_bg)" ;;
                *)   cstart=''                               ;;
            esac
            tagname=${tag:1}
            if [[ "$tagname" =~ ^(slack|mail|irc|chat)$ ]]; then
                tagname="^i(/home/nate/.local/share/icons/$tagname.xbm)"
            else
                tagname=" $tagname "
            fi
            dzenstring="${cstart}^ca(1,herbstclient use ${tag:1})$tagname^ca()^fg()^bg()"
            echo -n "$dzenstring"
        done
        echo "| $windowtitle"

        # Update tags and title
        read line || exit
        hook=( $line )
        case "${hook[0]}" in
            tag*) tags=( $(herbstclient tag_status) ) ;;
            quit_panel*) exit ;;
            focus_changed|window_title_changed)
                windowtitle="^fg($dzen_fg)^bg($used_bg)${hook[@]:2}^fg()^bg()"
                ;;
        esac
    done
} | dzen2 -h 16 -fn 'DejaVu Sans Mono:size=8' -ta l -sa l \
          -x $x -y $y -w $(($width-350)) \
          -fg "$dzen_fg" -bg "$dzen_bg" &
pids+=($!)

dzen2 -h 16 -fn 'DejaVu Sans Mono:size=8' -ta l -sa l \
      -x $(($x+$width-350)) -y $y -w 350 \
      -fg "$dzen_fg" -bg "$dzen_bg" < $CONKY_PIPE &
pids+=($!)

if [ $monitor == 0 ]; then
    sleep .25
    stalonetray &
    pids+=($!)
fi

herbstclient --wait '^(quit_panel|reload).*'
kill -TERM ${pids[*]}
exit 0
