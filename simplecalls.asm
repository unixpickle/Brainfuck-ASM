%macro	exit 1
	; do this first so that we do not overwrite
	; eax.
	mov ebx, %1
	mov eax, 1
	push ebx
	push eax
	int 80h
	add esp, 8

%endmacro

; print(str, length)
%macro	print 2
	; push so that we don't overwrite registers
	push %1
	push %2	
	
	pop edx
	pop ecx
	mov eax, 4			; write
	mov ebx, 1			; stdout
	
	push edx
	push ecx
	push ebx
	push eax
	int 80h
	add esp, 16

%endmacro

%macro	write 3
	push %1
	push %2
	push %3
	
	pop edx
	pop ecx
	pop ebx
	mov eax, 4
	
	push edx
	push ecx
	push ebx
	push eax
	
	int 80h
	add esp, 16

%endmacro
