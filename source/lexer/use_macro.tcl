use_macro:
	push	[free_additional_memory]
	push	[macro_symbols]
	mov	[macro_symbols],0
	push	[counter_limit]
	push	dword [edx+4]
	mov	dword [edx+4],1
	push	edx
	mov	ebx,esi
	mov	esi,[edx+8]
	mov	eax,[edx+12]
	mov	[macro_line],eax
	mov	[counter_limit],0
	xor	ebp,ebp
      process_macro_arguments:
	mov	al,[esi]
	or	al,al
	jz	arguments_end
	cmp	al,'{'
	je	arguments_end
	inc	esi
	cmp	al,'['
	jne	get_macro_arguments
	mov	ebp,esi
	inc	esi
	inc	[counter_limit]
      get_macro_arguments:
	call	get_macro_argument
	lods	byte [esi]
	cmp	al,','
	je	next_argument
	cmp	al,']'
	je	next_arguments_group
	cmp	al,'&'
	je	arguments_end
	dec	esi
	jmp	arguments_end
      next_argument:
	cmp	byte [ebx],','
	jne	process_macro_arguments
	inc	ebx
	jmp	process_macro_arguments
      next_arguments_group:
	cmp	byte [ebx],','
	jne	arguments_end
	inc	ebx
	inc	[counter_limit]
	mov	esi,ebp
	jmp	process_macro_arguments
      get_macro_argument:
	lods	byte [esi]
	movzx	ecx,al
	mov	eax,[counter_limit]
	call	add_macro_symbol
	add	esi,ecx
	xor	eax,eax
	mov	[default_argument_value],eax
	cmp	byte [esi],'*'
	je	required_value
	cmp	byte [esi],':'
	je	get_default_value
	cmp	byte [esi],'='
	jne	default_value_ok
      get_default_value:
	inc	esi
	mov	[default_argument_value],esi
	or	[skip_default_argument_value],-1
	call	skip_macro_argument_value
	jmp	default_value_ok
      required_value:
	inc	esi
	or	[default_argument_value],-1
      default_value_ok:
	xchg	esi,ebx
	mov	[edx+12],esi
	mov	[skip_default_argument_value],0
	cmp	byte [ebx],'&'
	je	greedy_macro_argument
	call	skip_macro_argument_value
	call	finish_macro_argument
	jmp	got_macro_argument
      greedy_macro_argument:
	call	skip_foreign_line
	dec	esi
	mov	eax,[edx+12]
	mov	ecx,esi
	sub	ecx,eax
	mov	[edx+8],ecx
      got_macro_argument:
	xchg	esi,ebx
	cmp	dword [edx+8],0
	jne	macro_argument_ok
	mov	eax,[default_argument_value]
	or	eax,eax
	jz	macro_argument_ok
	cmp	eax,-1
	je	invalid_macro_arguments
	mov	[edx+12],eax
	call	finish_macro_argument
      macro_argument_ok:
	ret
      finish_macro_argument:
	mov	eax,[edx+12]
	mov	ecx,esi
	sub	ecx,eax
	cmp	byte [eax],'<'
	jne	argument_value_length_ok
	inc	dword [edx+12]
	sub	ecx,2
	or	ecx,80000000h
      argument_value_length_ok:
	mov	[edx+8],ecx
	ret
      arguments_end:
	cmp	byte [ebx],0
	jne	invalid_macro_arguments
	mov	eax,[esp+4]
	dec	eax
	call	process_macro
	pop	edx
	pop	dword [edx+4]
	pop	[counter_limit]
	pop	[macro_symbols]
	pop	[free_additional_memory]
	jmp	line_preprocessed
