prepare_match:
	call	skip_pattern
	mov	[value_type],80h+10b
	call	process_symbolic_constants
	jmp	parameters_skipped
      skip_pattern:
	lods	byte [esi]
	or	al,al
	jz	invalid_macro_arguments
	cmp	al,','
	je	pattern_skipped
	cmp	al,22h
	je	skip_quoted_string_in_pattern
	cmp	al,1Ah
	je	skip_symbol_in_pattern
	cmp	al,'='
	jne	skip_pattern
	mov	al,[esi]
	cmp	al,1Ah
	je	skip_pattern
	cmp	al,22h
	je	skip_pattern
	inc	esi
	jmp	skip_pattern
      skip_symbol_in_pattern:
	lods	byte [esi]
	movzx	eax,al
	add	esi,eax
	jmp	skip_pattern
      skip_quoted_string_in_pattern:
	lods	dword [esi]
	add	esi,eax
	jmp	skip_pattern
      pattern_skipped:
	ret
