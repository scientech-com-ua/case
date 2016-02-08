process_macro_operators:
	xor	dl,dl
	mov	ebp,edi
      before_macro_operators:
	mov	edi,esi
	lods	byte [esi]
	cmp	al,'`'
	je	symbol_conversion
	cmp	al,'#'
	je	concatenation
	cmp	al,1Ah
	je	symbol_before_macro_operators
	cmp	al,3Bh
	je	no_more_macro_operators
	cmp	al,22h
	je	string_before_macro_operators
	xor	dl,dl
	or	al,al
	jnz	before_macro_operators
	mov	edi,esi
	ret
      no_more_macro_operators:
	mov	edi,ebp
	ret
      symbol_before_macro_operators:
	mov	dl,1Ah
	mov	ebx,esi
	lods	byte [esi]
	movzx	ecx,al
	jecxz	symbol_before_macro_operators_ok
	mov	edi,esi
	cmp	byte [esi],'\'
	je	escaped_symbol
      symbol_before_macro_operators_ok:
	add	esi,ecx
	jmp	before_macro_operators
      string_before_macro_operators:
	mov	dl,22h
	mov	ebx,esi
	lods	dword [esi]
	add	esi,eax
	jmp	before_macro_operators
      escaped_symbol:
	dec	byte [edi-1]
	dec	ecx
	inc	esi
	cmp	ecx,1
	rep	movs byte [edi],[esi]
	jne	after_macro_operators
	mov	al,[esi-1]
	mov	ecx,ebx
	mov	ebx,characters
	xlat	byte [ebx]
	mov	ebx,ecx
	or	al,al
	jnz	after_macro_operators
	sub	edi,3
	mov	al,[esi-1]
	stos	byte [edi]
	xor	dl,dl
	jmp	after_macro_operators
      reduce_symbol_conversion:
	inc	esi
      symbol_conversion:
	mov	edx,esi
	mov	al,[esi]
	cmp	al,1Ah
	jne	symbol_character_conversion
	lods	word [esi]
	movzx	ecx,ah
	lea	ebx,[edi+3]
	jecxz	convert_to_quoted_string
	cmp	byte [esi],'\'
	jne	convert_to_quoted_string
	inc	esi
	dec	ecx
	dec	ebx
	jmp	convert_to_quoted_string
      symbol_character_conversion:
	cmp	al,22h
	je	after_macro_operators
	cmp	al,'`'
	je	reduce_symbol_conversion
	lea	ebx,[edi+5]
	xor	ecx,ecx
	or	al,al
	jz	convert_to_quoted_string
	cmp	al,'#'
	je	convert_to_quoted_string
	inc	ecx
      convert_to_quoted_string:
	sub	ebx,edx
	ja	shift_line_data
	mov	al,22h
	mov	dl,al
	stos	byte [edi]
	mov	ebx,edi
	mov	eax,ecx
	stos	dword [edi]
	rep	movs byte [edi],[esi]
	cmp	edi,esi
	je	before_macro_operators
	jmp	after_macro_operators
      shift_line_data:
	push	ecx
	mov	edx,esi
	lea	esi,[ebp-1]
	add	ebp,ebx
	lea	edi,[ebp-1]
	lea	ecx,[esi+1]
	sub	ecx,edx
	std
	rep	movs byte [edi],[esi]
	cld
	pop	eax
	sub	edi,3
	mov	dl,22h
	mov	[edi-1],dl
	mov	ebx,edi
	mov	[edi],eax
	lea	esi,[edi+4+eax]
	jmp	before_macro_operators
      concatenation:
	cmp	dl,1Ah
	je	symbol_concatenation
	cmp	dl,22h
	je	string_concatenation
      no_concatenation:
	cmp	esi,edi
	je	before_macro_operators
	jmp	after_macro_operators
      symbol_concatenation:
	cmp	byte [esi],1Ah
	jne	no_concatenation
	inc	esi
	lods	byte [esi]
	movzx	ecx,al
	jecxz	do_symbol_concatenation
	cmp	byte [esi],'\'
	je	concatenate_escaped_symbol
      do_symbol_concatenation:
	add	[ebx],cl
	jc	name_too_long
	rep	movs byte [edi],[esi]
	jmp	after_macro_operators
      concatenate_escaped_symbol:
	inc	esi
	dec	ecx
	jz	do_symbol_concatenation
	movzx	eax,byte [esi]
	cmp	byte [characters+eax],0
	jne	do_symbol_concatenation
	sub	esi,3
	jmp	no_concatenation
      string_concatenation:
	cmp	byte [esi],22h
	je	do_string_concatenation
	cmp	byte [esi],'`'
	jne	no_concatenation
      concatenate_converted_symbol:
	inc	esi
	mov	al,[esi]
	cmp	al,'`'
	je	concatenate_converted_symbol
	cmp	al,22h
	je	do_string_concatenation
	cmp	al,1Ah
	jne	concatenate_converted_symbol_character
	inc	esi
	lods	byte [esi]
	movzx	ecx,al
	jecxz	finish_concatenating_converted_symbol
	cmp	byte [esi],'\'
	jne	finish_concatenating_converted_symbol
	inc	esi
	dec	ecx
      finish_concatenating_converted_symbol:
	add	[ebx],ecx
	rep	movs byte [edi],[esi]
	jmp	after_macro_operators
      concatenate_converted_symbol_character:
	or	al,al
	jz	after_macro_operators
	cmp	al,'#'
	je	after_macro_operators
	inc	dword [ebx]
	movs	byte [edi],[esi]
	jmp	after_macro_operators
      do_string_concatenation:
	inc	esi
	lods	dword [esi]
	mov	ecx,eax
	add	[ebx],eax
	rep	movs byte [edi],[esi]
      after_macro_operators:
	lods	byte [esi]
	cmp	al,'`'
	je	symbol_conversion
	cmp	al,'#'
	je	concatenation
	stos	byte [edi]
	cmp	al,1Ah
	je	symbol_after_macro_operators
	cmp	al,3Bh
	je	no_more_macro_operators
	cmp	al,22h
	je	string_after_macro_operators
	xor	dl,dl
	or	al,al
	jnz	after_macro_operators
	ret
      symbol_after_macro_operators:
	mov	dl,1Ah
	mov	ebx,edi
	lods	byte [esi]
	stos	byte [edi]
	movzx	ecx,al
	jecxz	symbol_after_macro_operatorss_ok
	cmp	byte [esi],'\'
	je	escaped_symbol
      symbol_after_macro_operatorss_ok:
	rep	movs byte [edi],[esi]
	jmp	after_macro_operators
      string_after_macro_operators:
	mov	dl,22h
	mov	ebx,edi
	lods	dword [esi]
	stos	dword [edi]
	mov	ecx,eax
	rep	movs byte [edi],[esi]
	jmp	after_macro_operators
