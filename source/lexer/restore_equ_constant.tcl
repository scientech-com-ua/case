restore_equ_constant:
	mov	ch,10b
      restore_preprocessor_symbol:
	push	ecx
	lods	byte [esi]
	cmp	al,1Ah
	jne	invalid_name
	lods	byte [esi]
	mov	cl,al
	call	get_preprocessor_symbol
	jc	no_symbol_to_restore
	mov	dword [edx+4],0
	jmp	symbol_restored
      no_symbol_to_restore:
	add	esi,ecx
      symbol_restored:
	pop	ecx
	lods	byte [esi]
	cmp	al,','
	je	restore_preprocessor_symbol
	or	al,al
	jnz	extra_characters_on_line
	jmp	line_preprocessed
