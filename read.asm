read:	; int read (int fd) (returns int character)
	push ebp
	mov ebp, esp
	sub esp, 1

	mov eax, 3				; read
	mov ebx, [ebp + 8]		; give the file descriptor
	mov ecx, esp			; give the stack as an address
	mov edx, 1				; read 1 byte
	push edx
	push ecx
	push ebx
	push eax
	int 80h
	add esp, 16
	cmp eax, 1				; if they didn't read 1 byte
	jne read_error			; there was an error.
	xor eax, eax
	mov ah, [esp]			; get the byte that was read
	jmp read_done
read_error:
	mov eax, -1
read_done:
	mov esp, ebp
	pop ebp
	ret
