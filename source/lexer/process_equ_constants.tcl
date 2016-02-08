process_equ_constants:
	mov	[value_type],10b
      process_symbolic_constants:
	mov	ebp,esi
	lods	byte [esi]
	cmp	al,1Ah
	je	check_symbol
	cmp	al,22h
	je	ignore_string
	cmp	al,'{'
	je	check_brace
	or	al,al
	jnz	process_symbolic_constants
	ret
      ignore_string:
	lods	dword [esi]
	add	esi,eax
	jmp	process_symbolic_constants
      check_brace:
	test	[value_type],80h
	jz	process_symbolic_constants
	ret
      no_replacing:
	movzx	ecx,byte [esi-1]
	add	esi,ecx
	jmp	process_symbolic_constants
      check_symbol:
	mov	cl,[esi]
	inc	esi
	mov	ch,[value_type]
	call	get_preprocessor_symbol
	jc	no_replacing
	mov	[current_section],edi
      replace_symbolic_constant:
	mov	ecx,[edx+12]
	mov	edx,[edx+8]
	xchg	esi,edx
	call	move_data
	mov	esi,edx
      process_after_replaced:
	lods	byte [esi]
	cmp	al,1Ah
	je	symbol_after_replaced
	stos	byte [edi]
	cmp	al,22h
	je	string_after_replaced
	cmp	al,'{'
	je	brace_after_replaced
	or	al,al
	jnz	process_after_replaced
	mov	ecx,edi
	sub	ecx,esi
	mov	edi,ebp
	call	move_data
	mov	esi,edi
	ret
      move_data:
	lea	eax,[edi+ecx]
	cmp	eax,[memory_end]
	jae	out_of_memory
	shr	ecx,1
	jnc	movsb_ok
	movs	byte [edi],[esi]
      movsb_ok:
	shr	ecx,1
	jnc	movsw_ok
	movs	word [edi],[esi]
      movsw_ok:
	rep	movs dword [edi],[esi]
	ret
      string_after_replaced:
	lods	dword [esi]
	stos	dword [edi]
	mov	ecx,eax
	call	move_data
	jmp	process_after_replaced
      brace_after_replaced:
	test	[value_type],80h
	jz	process_after_replaced
	mov	edx,edi
	mov	ecx,[current_section]
	sub	edx,ecx
	sub	ecx,esi
	rep	movs byte [edi],[esi]
	mov	ecx,edi
	sub	ecx,esi
	mov	edi,ebp
	call	move_data
	lea	esi,[ebp+edx]
	ret
      symbol_after_replaced:
	mov	cl,[esi]
	inc	esi
	mov	ch,[value_type]
	call	get_preprocessor_symbol
	jnc	replace_symbolic_constant
	movzx	ecx,byte [esi-1]
	mov	al,1Ah
	mov	ah,cl
	stos	word [edi]
	call	move_data
	jmp	process_after_replaced
