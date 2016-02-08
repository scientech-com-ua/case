define_instant_macro:
	mov	al,[macro_status]
	and	al,0F0h
	or	al,8+1
	mov	[macro_status],al
	mov	eax,[current_line]
	mov	[error_line],eax
	mov	[instant_macro_start],esi
	cmp	[base_code],10h
	je	prepare_match
      skip_parameters:
	lods	byte [esi]
	or	al,al
	jz	parameters_skipped
	cmp	al,'{'
	je	parameters_skipped
	cmp	al,22h
	je	skip_quoted_parameter
	cmp	al,1Ah
	jne	skip_parameters
	lods	byte [esi]
	movzx	eax,al
	add	esi,eax
	jmp	skip_parameters
      skip_quoted_parameter:
	lods	dword [esi]
	add	esi,eax
	jmp	skip_parameters
      parameters_skipped:
	dec	esi
	mov	[parameters_end],esi
	lods	byte [esi]
	cmp	al,'{'
	je	found_macro_block
	or	al,al
	jnz	invalid_macro_arguments
	jmp	line_preprocessed
