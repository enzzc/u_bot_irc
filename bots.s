;;; assemble with:  fasm botd.s
;;;
;;; Author: Enzo Calamia
;;; License: CC0 1.0 Universal
;;; Date: Sat Nov 12 2011
;;; Descpriton: Yet another useless IRC bot...
;;; Version: 3

PORT equ $0b1a                  ; 6667
HOST equ 830528449              ; 193.219.128.49
CHAN equ "#chan_name"
NAME equ "botInAsm3"


format ELF executable 3         ;  ELF32  |  e_type: EXEC (executable)  |  OSABI: Linux (3)
entry start

segment readable executable     ; .text
start:
        mov eax, 2              ; SYS_FORK = 2
        int $80                 ; to make a daemon

        test eax, eax
        jz Main

        jmp exit2
        

Main:   call socket
        call connect
        call init_irc
        call join_chan
        call rw_loop
        


exit:   mov eax, 6              ; SYS_CLOSE = 6
        mov ebx, esi            ; close fd of socket
        int $80

exit2:  mov eax, 1              ; SYS_EXIT = 1
        xor ebx, ebx            ; exit(0)
        int $80


fail_sock:
        mov eax, 4
        mov ebx, 2
        mov ecx, err_sock
        mov edx, 13
        int $80
        jmp exitf

fail_conn:
        mov eax, 4
        mov ebx, 2
        mov ecx, err_conn
        mov edx, 39
        int $80
        jmp exitf

exitf:
        mov eax, 1              ; SYS_CLOSE = 1
        mov ebx, -1             ; exit(-1)
        int $80


;; socket(PF_INET, SOCK_STREAM, 0)
socket:
	push ebp
        mov ebp, esp

        push 0                  ; protocol = 0
        push 1                  ; SOCK_STREAM = 1
        push 2                  ; AF_INET = 2

        mov eax, $66            ; SYS_SOCKETCALL = $66
        mov ebx, 1              ; SYS_SOCKET = 1
        mov ecx, esp
        int $80                 ; eax contains a socket fd, or -1

        cmp eax, -1             ; if ERROR
        je fail_sock            ; then exit(-1)

        mov esi, eax            ; save the fd

        leave
        ret

	

;; connect(fd, [AF_INET, port, IPv4], size)
connect:
        push ebp
        mov ebp, esp

        ;; sockaddr strcuture
        push dword 0
        push dword 0
        
        push dword HOST               ; irc.hackerzvoice.net
        push word PORT               ; port
        push word 2             ; AF_INET = 2
        mov ecx, esp

        push 16                 ; size
        push ecx                ; [AF_INET, port, IPv4]
        push dword esi          ; fd of socket

        mov eax, $66            ; SYS_SOCKETCALL
        mov ebx, 3              ; SYS_CONNECT = 3
        mov ecx, esp            ; connect(args)
        int $80

        cmp eax, -1
        je fail_conn

        leave
        ret
	

init_irc:
        mov eax, 4
        mov ebx, esi
        mov ecx, init
        mov edx, init.len
        int $80

        ret

join_chan:      
        mov eax, 4
        mov ebx, esi
        mov ecx, join
        mov edx, join.len
        int $80

        ret


rw_loop:
        
    .get_put:
        mov eax, 3              ; SYS_READ = 3
        mov ebx, esi
        mov ecx, buff
        mov edx, 1024
        int $80

        mov eax, 4
        mov ebx, 1
        mov ecx, buff
        mov edx, 1024
        int $80

        call parse
        call bzero
        call join_chan          ; If we are kicked...

        jmp .get_put


parse:
        push ebp
        mov ebp, esp
        
        mov ebx, buff
        
        cmp dword [ebx], "PING"
        je .send_pong

        cmp dword [ebx], "ERRO" ; if ERROR, close the program pas comme un porc
        je exit

        ;; recognize a prefixed command '%'
        ;; TODO: fix BO using a counter (edx or ecx)
       
      @@:
        cmp byte [ebx], $a      ; if byte[ebx] == \r
        je .done
	
	inc ebx
        cmp byte [ebx], '%'
        jne @b
	
        inc ebx
        cmp dword [ebx], "help"
        je .send_help

        cmp dword [ebx], "1337"
        je .send_1337

        cmp word [ebx], "42"
        je .send_42
        
      .done:   
        leave
        ret
	

  .send_pong:

        push $20
        push "PONG"
        mov eax, 4
        mov ebx, esi
        mov ecx, esp
        mov edx, 5
        int $80                 ; send "PONG "


        mov ecx, buff           ; "PING :xxxx..."
        add ecx, 5              ; "xxxxxxx\r\n" (buffer minus 5 firsts chars)

        mov eax, 4
        mov ebx, esi
        ;; ecx is already set
        mov edx, 512
        int $80                 ; send ":xxxxx\r\n"


        leave
        ret
	

   .send_help:
	
        mov eax, 4
        mov ebx, esi
        mov ecx, msg
        mov edx, msg.len
        int $80

        mov eax, 4
        mov ebx, esi
        mov ecx, help
        mov edx, help.len
        int $80

        leave
        ret

    .send_1337:
	
        mov eax, 4
        mov ebx, esi
        mov ecx, msg
        mov edx, msg.len
        int $80

        mov eax, 4
        mov ebx, esi
        mov ecx, leet
        mov edx, leet.len
        int $80

        leave
        ret

    .send_42:
	
        mov eax, 4
        mov ebx, esi
        mov ecx, msg
        mov edx, msg.len
        int $80

        mov eax, 4
        mov ebx, esi
        mov ecx, ans
        mov edx, ans.len
        int $80

        leave
        ret


bzero:
        mov ebx, buff
        xor eax, eax
        
      .SET0:
      
        mov dword [ebx], 0
        add ebx, 4
        add eax, 4

        cmp eax, 1024

        jne .SET0

        ret
        



segment readable writable       ; .data
	
        
err_sock:  db "*** fail: socket", $a
err_sock.len = $-err_sock

err_conn:  db "*** fail: unable to connect to remote host", $a
err_conn.len = $-err_conn


init:   db "NICK ", NAME, $d, $a, "USER ", NAME, " 0 * :botinasm1", $d, $a
init.len = $-init

pong:   db "PONG "
pong.len = $-pong

join:   db "JOIN ", CHAN , $d, $a
join.len = $-join

msg:    db "PRIVMSG ", CHAN, " :"
msg.len = $-msg

help:   db "%help: get help (of course) \ %1337: fun and useless \ %42: you already have the answer", $d, $a
help.len = $-help

leet:   db "MCCCXXXVII \ 1337 divides 39^15-1 \ Prime factorisation: 7 * 191 \ Bin: 0b10100111001 \ Hex: 0x539", $d, $a
leet.len = $-leet

ans:    db "Answer to the Ultimate Question of Life, the Universe, and Everything", $d, $a
ans.len = $-ans

buff:   rb 2048
