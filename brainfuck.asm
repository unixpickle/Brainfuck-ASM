
section .data
	argErrorStr:		db 'Usage: brainfuck file.bf', 10
	argErrorLen:		equ $-argErrorStr	; clever :)
	openErrorStr:		db 'Failed to open file.', 10
	openErrorLen:		equ $-openErrorStr
	fooStr:				db 'Foo!', 10
	fooLen:				equ $-fooStr

section .bss
	theBuffer:			resb 4000	; byte buffer is 4000 bytes
	theOffset:			resq 1		; reserve one quad (int)
	instruction:		resq 1		; the instruction ptr
	theCode:			resb 4000	; the code buffer

section .text
	global start

%include "strlen.asm"
%include "simplecalls.asm"
%include "read.asm"

start:
	push ebp
	mov ebp, esp
	
	; bzero theOffset
	mov eax, 0
	mov [theOffset], eax
	call getArgCount			; set eax to argc
	cmp eax, 2
	jne myArgumentError			; invalid argument count
	jmp myArugmentError_not
myArgumentError:
	jmp argumentError
myArugmentError_not:
	
	; get the file name
	mov ecx, [ebp+12]
	; ecx = string file name

	mov eax, 5					; Open
	mov ebx, ecx				; path
	mov ecx, 0x200				; flags = O_CREAT
	or	ecx, 0x002				; flags |= O_RDRW
	mov edx, 777o				; mode = OCTAL rwx-rwx-rwx
	push edx
	push ecx
	push ebx
	push eax
	int 80h
	add	esp, 16

	cmp eax, -1
	je myFailOpen
	jmp myFailOpen_not
myFailOpen:
	jmp failOpen
myFailOpen_not:
	push dword 0				; the current index
	push eax					; save the file descriptor

; this will be jumped to until the file has
; been read onto the stack
bf_readloop:
	call read
	cmp eax, -1
	je bf_doneread
	mov ecx, theCode			; get the start of the buffer
	mov esi, [esp + 4]			; get the current buffer index
	lea edx, [ecx + esi]		; edx = &ecx[esi]
	mov [edx], ah				; move the byte read into edx
	inc esi						; esi += 1
	mov [esp + 4], esi			; save esi
	jmp bf_readloop

bf_doneread:
	mov edx, 0
	mov [instruction], edx

; exec loop will be called until the instruction pointer
; is at the end of the buffer.
bf_execloop:
	mov ebx, [esp + 4]			; buffer length
	mov ecx, [instruction]
	cmp ebx, ecx
	jne myBrainfuck_cont1
	jmp bf_done
myBrainfuck_cont1:
	mov esi, theCode
	mov ah, [esi + ecx]
	jmp bf_exec					; bf_exec jumps to bf_execloop

bf_exec:						; used to execute the current function in %ah
bf_check_foo:
	cmp ah, 66h 				; check for f (print foo)
	jne bf_check_incr
	call _bf_printfoo
	jmp bf_exec_fin
bf_check_incr:
	cmp ah, 3Eh					; check for > (incr addr)
	jne bf_check_decr
	call _bf_incr_ptr			; called only if equal
	jmp bf_exec_fin
bf_check_decr:
	cmp ah, 3Ch					; check for < (decr addr)
	jne bf_check_addv
	call _bf_dec_ptr
	jmp bf_exec_fin
bf_check_addv:					; check add value
	cmp ah, 2Bh					; check for +
	jne bf_check_subv
	call _bf_add_char
	jmp bf_exec_fin
bf_check_subv:
	cmp ah, 2Dh					; check for -
	jne bf_check_print
	call _bf_sub_char
	jmp bf_exec_fin
bf_check_print:
	cmp ah, 2Eh					; putchar '.'
	jne bf_check_read
	call _bf_print_char
	jmp bf_exec_fin
bf_check_read:
	cmp ah, 2Ch					; getchar ','
	jne bf_check_loop
	call _bf_read_char
	jmp bf_exec_fin
bf_check_loop:
	cmp ah, 5Dh					; loop ']'
	jne bf_exec_fin
	call _bf_loop_back
	jmp bf_exec_fin
bf_exec_fin:
	mov edx, [instruction]
	inc edx
	mov [instruction], edx
	jmp bf_execloop

_bf_printfoo:      				; prints foo
	pusha						; push all general purpose registers
	print fooStr, fooLen
	popa						; pop all general purpose registers
	ret

_bf_incr_ptr:
	pusha
	mov eax, [theOffset]
	inc eax
	mov [theOffset], eax
	popa
	ret

_bf_dec_ptr:
	pusha
	mov eax, [theOffset]
	sub eax, 1
	mov [theOffset], eax
	popa
	ret

_bf_add_char:
	pusha
	mov ecx, [theOffset]
	mov ebx, theBuffer
	mov al, [ebx+ecx]
	inc al
	mov [ebx+ecx], al
	popa
	ret

_bf_sub_char:
	pusha
	mov ecx, [theOffset]
	mov ebx, theBuffer
	mov al, [ebx+ecx]
	sub al, 1
	mov [ebx+ecx], al
	popa
	ret

_bf_print_char:
	pusha						; we fuck with registers A LOT
	push ebp
	mov ebp, esp
	sub esp, 1
	mov ecx, [theOffset]
	mov ebx, theBuffer
	mov al, [ebx+ecx]
	mov [esp], al
	
	mov edx, esp				; the print macro doesn't like print of esp
	print edx, 1

	mov esp, ebp
	pop ebp
	popa
	ret

_bf_read_char:
	pusha
	push ebp
	mov ebp, esp
	
	mov ecx, 0					; stdin
	push ecx
	call read
	cmp eax, -1
	je bf_read_fail
	jmp bf_read_cont
bf_read_fail:
	exit 0
bf_read_cont:
	mov ecx, [theOffset]
	mov ebx, theBuffer
	mov [ebx+ecx], ah			; ah is set to the char that was read
	
	mov esp, ebp
	pop ebp
	popa
	ret
	
_bf_loop_back:
	mov esi, [theOffset]
	mov al, [theBuffer + esi]
	cmp al, 0
	jne bf_loopback_cont		; if current byte = 0, no loop
	ret
bf_loopback_cont:
	push ebp
	mov ebp, esp 				; stack frame
	mov edi, 1
	mov edx, [instruction]
	mov esi, theCode
	; edi is our count of [ that we need
	; esi is the beginning of our content (code)
	; edx is our instruction pointer (in esp + 8)
	
bf_loopback_loop:
	cmp edx, 0
	jne bf_loopback_cont2		; we can't go down any further
	exit 1
bf_loopback_cont2:
	cmp edi, 0
	je bf_loopback_end			; we have reached a zero loop level!
	sub edx, 1
	mov ah, [esi + edx]
	cmp ah, 5Bh					; check for '['
	je bf_loopback_sub
	cmp ah, 5Dh					; check for ']'
	je bf_loopback_add	
	jmp bf_loopback_repeat		
bf_loopback_sub:
	sub edi, 1
	jmp bf_loopback_repeat
bf_loopback_add:
	add edi, 1
	jmp bf_loopback_repeat
bf_loopback_repeat:
	jmp bf_loopback_loop
bf_loopback_end:
	mov [instruction], edx
	mov esp, ebp
	pop ebp
	ret

bf_done:
	pop eax
	exit 0
	
	mov esp, ebp
	pop ebp
	ret

argumentError:
	print argErrorStr, argErrorLen
	exit 0

failOpen:
	print openErrorStr, openErrorLen
	exit 0

getArgCount:
	push ebp
	mov ebp, esp
	; start out with ebp, add up to the argc, and GET THAT SUCKER
	mov edx, ebp
	add edx, 12					; return address + stack frame + stack frame
	mov	eax, [edx]
	
	mov esp, ebp
	pop ebp
	ret
