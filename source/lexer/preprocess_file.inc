preprocess_file:
	push	[memory_end]
	push	esi
	mov	al,2
	xor	edx,edx
	call	lseek
	push	eax
	xor	al,al
	xor	edx,edx
	call	lseek
	pop	ecx
	mov	edx,[memory_end]
	dec	edx
	mov	byte [edx],1Ah
	sub	edx,ecx
	jc	out_of_memory
	mov	esi,edx
	cmp	edx,edi
	jbe	out_of_memory
	mov	[memory_end],edx
	call	read
	call	close
	pop	edx
	xor	ecx,ecx
	mov	ebx,esi
      preprocess_source:
	inc	ecx
	mov	[current_line],edi
	mov	eax,edx
	stos	dword [edi]
	mov	eax,ecx
	stos	dword [edi]
	mov	eax,esi
	sub	eax,ebx
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	push	ebx edx
	call	convert_line
	call	preprocess_line
	pop	edx ebx
      next_line:
	cmp	byte [esi-1],0
	je	file_end
	cmp	byte [esi-1],1Ah
	jne	preprocess_source
      file_end:
	pop	[memory_end]
	clc
	ret
