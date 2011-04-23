strlen: ; int strlen(char * string)
	push ebp
	mov ebp, esp
	mov edi, [ebp + 8]		; str argument
	mov esi, 0
	
strlen_loop:
	mov al, [edi+esi]
	cmp al, 0
	je strlen_done
	inc esi
	jmp strlen_loop

strlen_done:
	mov eax, esi
	mov esp, ebp
	pop ebp
	ret
	
