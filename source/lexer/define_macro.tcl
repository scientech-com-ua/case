define_macro:
	xor	ch,ch
      make_macro:
	lods	byte [esi]
	cmp	al,1Ah
	jne	invalid_name
	lods	byte [esi]
	mov	cl,al
	call	add_preprocessor_symbol
	mov	eax,[current_line]
	mov	[edx+12],eax
	movzx	eax,byte [esi-1]
	add	esi,eax
	mov	[edx+8],esi
	mov	al,[macro_status]
	and	al,0F0h
	or	al,1
	mov	[macro_status],al
	mov	eax,[current_line]
	mov	[error_line],eax
	xor	ebp,ebp
	lods	byte [esi]
	or	al,al
	jz	line_preprocessed
	cmp	al,'{'
	je	found_macro_block
	dec	esi
      skip_macro_arguments:
	lods	byte [esi]
	cmp	al,1Ah
	je	skip_macro_argument
	cmp	al,'['
	jne	invalid_macro_arguments
	or	ebp,-1
	jz	invalid_macro_arguments
	lods	byte [esi]
	cmp	al,1Ah
	jne	invalid_macro_arguments
      skip_macro_argument:
	movzx	eax,byte [esi]
	inc	esi
	add	esi,eax
	lods	byte [esi]
	cmp	al,':'
	je	macro_argument_with_default_value
	cmp	al,'='
	je	macro_argument_with_default_value
	cmp	al,'*'
	jne	macro_argument_end
	lods	byte [esi]
      macro_argument_end:
	cmp	al,','
	je	skip_macro_arguments
	cmp	al,'&'
	je	macro_arguments_finisher
	cmp	al,']'
	jne	end_macro_arguments
	not	ebp
      macro_arguments_finisher:
	lods	byte [esi]
      end_macro_arguments:
	or	ebp,ebp
	jnz	invalid_macro_arguments
	or	al,al
	jz	line_preprocessed
	cmp	al,'{'
	je	found_macro_block
	jmp	invalid_macro_arguments
      macro_argument_with_default_value:
	or	[skip_default_argument_value],-1
	call	skip_macro_argument_value
	inc	esi
	jmp	macro_argument_end
      skip_macro_argument_value:
	cmp	byte [esi],'<'
	jne	simple_argument
	mov	ecx,1
	inc	esi
      enclosed_argument:
	lods	byte [esi]
	or	al,al
	jz	invalid_macro_arguments
	cmp	al,1Ah
	je	enclosed_symbol
	cmp	al,22h
	je	enclosed_string
	cmp	al,'>'
	je	enclosed_argument_end
	cmp	al,'<'
	jne	enclosed_argument
	inc	ecx
	jmp	enclosed_argument
      enclosed_symbol:
	movzx	eax,byte [esi]
	inc	esi
	add	esi,eax
	jmp	enclosed_argument
      enclosed_string:
	lods	dword [esi]
	add	esi,eax
	jmp	enclosed_argument
      enclosed_argument_end:
	loop	enclosed_argument
	lods	byte [esi]
	or	al,al
	jz	argument_value_end
	cmp	al,','
	je	argument_value_end
	cmp	[skip_default_argument_value],0
	je	invalid_macro_arguments
	cmp	al,'{'
	je	argument_value_end
	cmp	al,'&'
	je	argument_value_end
	or	ebp,ebp
	jz	invalid_macro_arguments
	cmp	al,']'
	je	argument_value_end
	jmp	invalid_macro_arguments
      simple_argument:
	lods	byte [esi]
	or	al,al
	jz	argument_value_end
	cmp	al,','
	je	argument_value_end
	cmp	al,22h
	je	argument_string
	cmp	al,1Ah
	je	argument_symbol
	cmp	[skip_default_argument_value],0
	je	simple_argument
	cmp	al,'{'
	je	argument_value_end
	cmp	al,'&'
	je	argument_value_end
	or	ebp,ebp
	jz	simple_argument
	cmp	al,']'
	je	argument_value_end
      argument_symbol:
	movzx	eax,byte [esi]
	inc	esi
	add	esi,eax
	jmp	simple_argument
      argument_string:
	lods	dword [esi]
	add	esi,eax
	jmp	simple_argument
      argument_value_end:
	dec	esi
	ret
      find_macro_block:
	add	esi,2
	lods	byte [esi]
	or	al,al
	jz	line_preprocessed
	cmp	al,'{'
	jne	unexpected_characters
      found_macro_block:
	or	[macro_status],2
      skip_macro_block:
	lods	byte [esi]
	cmp	al,1Ah
	je	skip_macro_symbol
	cmp	al,comment_marker
	je	skip_macro_symbol
	cmp	al,22h
	je	skip_macro_string
	or	al,al
	jz	line_preprocessed
	cmp	al,'}'
	jne	skip_macro_block
	mov	al,[macro_status]
	and	[macro_status],0F0h
	test	al,8
	jnz	use_instant_macro
	cmp	byte [esi],0
	je	line_preprocessed
	mov	ecx,edi
	sub	ecx,esi
	mov	edx,esi
	lea	esi,[esi+ecx-1]
	lea	edi,[edi+1+16]
	mov	ebx,edi
	dec	edi
	std
	rep	movs byte [edi],[esi]
	cld
	mov	edi,edx
	xor	al,al
	stos	byte [edi]
	mov	esi,[current_line]
	mov	[current_line],edi
	mov	ecx,4
	rep	movs dword [edi],[esi]
	mov	edi,ebx
	jmp	initial_preprocessing_ok
      skip_macro_symbol:
	movzx	eax,byte [esi]
	inc	esi
	add	esi,eax
	jmp	skip_macro_block
      skip_macro_string:
	lods	dword [esi]
	add	esi,eax
	jmp	skip_macro_block
