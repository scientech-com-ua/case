process_macro:
	push	dword [macro_status]
	or	[macro_status],10h
	push	[counter]
	push	[macro_block]
	push	[macro_block_line]
	push	[macro_block_line_number]
	push	[struc_label]
	push	[struc_name]
	push	eax
	push	[current_line]
	lods	byte [esi]
	cmp	al,'{'
	je	macro_instructions_start
	or	al,al
	jnz	unexpected_characters
      find_macro_instructions:
	mov	[macro_line],esi
	add	esi,16+2
	lods	byte [esi]
	or	al,al
	jz	find_macro_instructions
	cmp	al,'{'
	je	macro_instructions_start
	cmp	al,comment_marker
	jne	unexpected_characters
	call	skip_foreign_symbol
	jmp	find_macro_instructions
      macro_instructions_start:
	mov	ecx,80000000h
	mov	[macro_block],esi
	mov	eax,[macro_line]
	mov	[macro_block_line],eax
	mov	[macro_block_line_number],ecx
	xor	eax,eax
	mov	[counter],eax
	cmp	[counter_limit],eax
	je	process_macro_line
	inc	[counter]
      process_macro_line:
	lods	byte [esi]
	or	al,al
	jz	process_next_line
	cmp	al,'}'
	je	macro_block_processed
	dec	esi
	mov	[current_line],edi
	lea	eax,[edi+10h]
	cmp	eax,[memory_end]
	jae	out_of_memory
	mov	eax,[esp+4]
	or	eax,eax
	jz	instant_macro_line_header
	stos	dword [edi]
	mov	eax,ecx
	stos	dword [edi]
	mov	eax,[esp]
	stos	dword [edi]
	mov	eax,[macro_line]
	stos	dword [edi]
	jmp	macro_line_header_ok
      instant_macro_line_header:
	mov	eax,[esp]
	add	eax,16
      find_defining_directive:
	inc	eax
	cmp	byte [eax-1],comment_marker
	je	defining_directive_ok
	cmp	byte [eax-1],1Ah
	jne	find_defining_directive
	push	eax
	movzx	eax,byte [eax]
	inc	eax
	add	[esp],eax
	pop	eax
	jmp	find_defining_directive
      defining_directive_ok:
	stos	dword [edi]
	mov	eax,ecx
	stos	dword [edi]
	mov	eax,[macro_line]
	stos	dword [edi]
	stos	dword [edi]
      macro_line_header_ok:
	or	[macro_status],20h
	push	ebx ecx
	test	[macro_status],0Fh
	jz	process_macro_line_element
	mov	ax,comment_marker
	stos	word [edi]
      process_macro_line_element:
	lea	eax,[edi+100h]
	cmp	eax,[memory_end]
	jae	out_of_memory
	lods	byte [esi]
	cmp	al,'}'
	je	macro_line_processed
	or	al,al
	jz	macro_line_processed
	cmp	al,1Ah
	je	process_macro_symbol
	cmp	al,comment_marker
	je	macro_foreign_line
	and	[macro_status],not 20h
	stos	byte [edi]
	cmp	al,22h
	jne	process_macro_line_element
      copy_macro_string:
	mov	ecx,[esi]
	add	ecx,4
	call	move_data
	jmp	process_macro_line_element
      process_macro_symbol:
	push	esi edi
	test	[macro_status],20h
	jz	not_macro_directive
	movzx	ecx,byte [esi]
	inc	esi
	mov	edi,macro_directives
	call	get_directive
	jnc	process_macro_directive
	dec	esi
	jmp	not_macro_directive
      process_macro_directive:
	mov	edx,eax
	pop	edi eax
	mov	byte [edi],0
	inc	edi
	pop	ecx ebx
	jmp	near edx
      not_macro_directive:
	and	[macro_status],not 20h
	movzx	ecx,byte [esi]
	inc	esi
	mov	eax,[counter]
	call	get_macro_symbol
	jnc	group_macro_symbol
	xor	eax,eax
	cmp	[counter],eax
	je	multiple_macro_symbol_values
	call	get_macro_symbol
	jc	not_macro_symbol
      replace_macro_symbol:
	pop	edi eax
	mov	ecx,[edx+8]
	mov	edx,[edx+12]
	or	edx,edx
	jz	replace_macro_counter
	and	ecx,not 80000000h
	xchg	esi,edx
	call	move_data
	mov	esi,edx
	jmp	process_macro_line_element
      group_macro_symbol:
	xor	eax,eax
	cmp	[counter],eax
	je	replace_macro_symbol
	push	esi edx
	sub	esi,ecx
	call	get_macro_symbol
	mov	ebx,edx
	pop	edx esi
	jc	replace_macro_symbol
	cmp	edx,ebx
	ja	replace_macro_symbol
	mov	edx,ebx
	jmp	replace_macro_symbol
      multiple_macro_symbol_values:
	inc	eax
	push	eax
	call	get_macro_symbol
	pop	eax
	jc	not_macro_symbol
	pop	edi
	push	ecx
	mov	ecx,[edx+8]
	mov	edx,[edx+12]
	xchg	esi,edx
	btr	ecx,31
	jc	enclose_macro_symbol_value
	rep	movs byte [edi],[esi]
	jmp	macro_symbol_value_ok
      enclose_macro_symbol_value:
	mov	byte [edi],'<'
	inc	edi
	rep	movs byte [edi],[esi]
	mov	byte [edi],'>'
	inc	edi
      macro_symbol_value_ok:
	cmp	eax,[counter_limit]
	je	multiple_macro_symbol_values_ok
	mov	byte [edi],','
	inc	edi
	mov	esi,edx
	pop	ecx
	push	edi
	sub	esi,ecx
	jmp	multiple_macro_symbol_values
      multiple_macro_symbol_values_ok:
	pop	ecx eax
	mov	esi,edx
	jmp	process_macro_line_element
      replace_macro_counter:
	mov	eax,[counter]
	and	eax,not 80000000h
	jz	group_macro_counter
	add	ecx,eax
	dec	ecx
	call	store_number_symbol
	jmp	process_macro_line_element
      group_macro_counter:
	mov	edx,ecx
	xor	ecx,ecx
      multiple_macro_counter_values:
	push	ecx edx
	add	ecx,edx
	call	store_number_symbol
	pop	edx ecx
	inc	ecx
	cmp	ecx,[counter_limit]
	je	process_macro_line_element
	mov	byte [edi],','
	inc	edi
	jmp	multiple_macro_counter_values
      store_number_symbol:
	cmp	ecx,0
	jge	numer_symbol_sign_ok
	neg	ecx
	mov	al,'-'
	stos	byte [edi]
      numer_symbol_sign_ok:
	mov	ax,1Ah
	stos	word [edi]
	push	edi
	mov	eax,ecx
	mov	ecx,1000000000
	xor	edx,edx
	xor	bl,bl
      store_number_digits:
	div	ecx
	push	edx
	or	bl,bl
	jnz	store_number_digit
	cmp	ecx,1
	je	store_number_digit
	or	al,al
	jz	number_digit_ok
	not	bl
      store_number_digit:
	add	al,30h
	stos	byte [edi]
      number_digit_ok:
	mov	eax,ecx
	xor	edx,edx
	mov	ecx,10
	div	ecx
	mov	ecx,eax
	pop	eax
	or	ecx,ecx
	jnz	store_number_digits
	pop	ebx
	mov	eax,edi
	sub	eax,ebx
	mov	[ebx-1],al
	ret
      not_macro_symbol:
	pop	edi esi
	mov	al,1Ah
	stos	byte [edi]
	mov	al,[esi]
	inc	esi
	stos	byte [edi]
	cmp	byte [esi],'.'
	jne	copy_raw_symbol
	mov	ebx,[esp+8+8]
	or	ebx,ebx
	jz	copy_raw_symbol
	cmp	al,1
	je	copy_struc_name
	xchg	esi,ebx
	movzx	ecx,byte [esi-1]
	add	[edi-1],cl
	jc	name_too_long
	rep	movs byte [edi],[esi]
	xchg	esi,ebx
      copy_raw_symbol:
	movzx	ecx,al
	rep	movs byte [edi],[esi]
	jmp	process_macro_line_element
      copy_struc_name:
	inc	esi
	xchg	esi,ebx
	movzx	ecx,byte [esi-1]
	mov	[edi-1],cl
	rep	movs byte [edi],[esi]
	xchg	esi,ebx
	mov	eax,[esp+8+12]
	cmp	byte [eax],comment_marker
	je	process_macro_line_element
	cmp	byte [eax],1Ah
	jne	disable_replaced_struc_name
	mov	byte [eax],comment_marker
	jmp	process_macro_line_element
      disable_replaced_struc_name:
	mov	ebx,[esp+8+8]
	push	esi edi
	lea	edi,[ebx-3]
	lea	esi,[edi-2]
	lea	ecx,[esi+1]
	sub	ecx,eax
	std
	rep	movs byte [edi],[esi]
	cld
	mov	word [eax],comment_marker
	pop	edi esi
	jmp	process_macro_line_element
      skip_foreign_symbol:
	lods	byte [esi]
	movzx	eax,al
	add	esi,eax
      skip_foreign_line:
	lods	byte [esi]
	cmp	al,1Ah
	je	skip_foreign_symbol
	cmp	al,comment_marker
	je	skip_foreign_symbol
	cmp	al,22h
	je	skip_foreign_string
	or	al,al
	jnz	skip_foreign_line
	ret
      skip_foreign_string:
	lods	dword [esi]
	add	esi,eax
	jmp	skip_foreign_line
      macro_foreign_line:
	call	skip_foreign_symbol
      macro_line_processed:
	mov	byte [edi],0
	inc	edi
	push	eax
	call	preprocess_line
	pop	eax
	pop	ecx ebx
	cmp	al,'}'
	je	macro_block_processed
      process_next_line:
	inc	ecx
	mov	[macro_line],esi
	add	esi,16+2
	jmp	process_macro_line
      macro_block_processed:
	call	close_macro_block
	jc	process_macro_line
	pop	[current_line]
	add	esp,12
	pop	[macro_block_line_number]
	pop	[macro_block_line]
	pop	[macro_block]
	pop	[counter]
	pop	eax
	and	al,0F0h
	and	[macro_status],0Fh
	or	[macro_status],al
	ret
