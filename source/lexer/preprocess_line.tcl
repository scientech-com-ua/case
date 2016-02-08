preprocess_line:
	mov	eax,esp
	sub	eax,100h
	jc	stack_overflow
	cmp	eax,[stack_limit]
	jb	stack_overflow
	push	ecx esi
      preprocess_current_line:
	mov	esi,[current_line]
	add	esi,16
	cmp	word [esi],comment_marker
	jne	line_start_ok
	add	esi,2
      line_start_ok:
	test	[macro_status],0F0h
	jnz	macro_preprocessing
	cmp	byte [esi],1Ah
	jne	not_fix_constant
	movzx	edx,byte [esi+1]
	lea	edx,[esi+2+edx]
	cmp	word [edx],031Ah
	jne	not_fix_constant
	mov	ebx,characters
	movzx	eax,byte [edx+2]
	xlat	byte [ebx]
	ror	eax,8
	mov	al,[edx+3]
	xlat	byte [ebx]
	ror	eax,8
	mov	al,[edx+4]
	xlat	byte [ebx]
	ror	eax,16
	cmp	eax,'fix'
	je	define_fix_constant
      not_fix_constant:
	call	process_fix_constants
	jmp	initial_preprocessing_ok
      macro_preprocessing:
	call	process_macro_operators
      initial_preprocessing_ok:
	mov	esi,[current_line]
	add	esi,16
	mov	al,[macro_status]
	test	al,2
	jnz	skip_macro_block
	test	al,1
	jnz	find_macro_block
      preprocess_instruction:
	mov	[current_offset],esi
	lods	byte [esi]
	movzx	ecx,byte [esi]
	inc	esi
	cmp	al,1Ah
	jne	not_preprocessor_symbol
	cmp	cl,3
	jb	not_preprocessor_directive
	push	edi
	mov	edi,preprocessor_directives
	call	get_directive
	pop	edi
	jc	not_preprocessor_directive
	mov	byte [edx-2],comment_marker
	jmp	near eax
      not_preprocessor_directive:
	xor	ch,ch
	call	get_preprocessor_symbol
	jc	not_macro
	mov	byte [ebx-2],comment_marker
	mov	[struc_name],0
	jmp	use_macro
      not_macro:
	mov	[struc_name],esi
	add	esi,ecx
	lods	byte [esi]
	cmp	al,':'
	je	preprocess_label
	cmp	al,1Ah
	jne	not_preprocessor_symbol
	lods	byte [esi]
	cmp	al,3
	jne	not_symbolic_constant
	mov	ebx,characters
	movzx	eax,byte [esi]
	xlat	byte [ebx]
	ror	eax,8
	mov	al,[esi+1]
	xlat	byte [ebx]
	ror	eax,8
	mov	al,[esi+2]
	xlat	byte [ebx]
	ror	eax,16
	cmp	eax,'equ'
	je	define_equ_constant
	mov	al,3
      not_symbolic_constant:
	mov	ch,1
	mov	cl,al
	call	get_preprocessor_symbol
	jc	not_preprocessor_symbol
	push	edx esi
	mov	esi,[struc_name]
	mov	[struc_label],esi
	sub	[struc_label],2
	mov	cl,[esi-1]
	mov	ch,10b
	call	get_preprocessor_symbol
	jc	struc_name_ok
	mov	ecx,[edx+12]
	add	ecx,3
	lea	ebx,[edi+ecx]
	mov	ecx,edi
	sub	ecx,[struc_label]
	lea	esi,[edi-1]
	lea	edi,[ebx-1]
	std
	rep	movs byte [edi],[esi]
	cld
	mov	edi,[struc_label]
	mov	esi,[edx+8]
	mov	ecx,[edx+12]
	add	[struc_name],ecx
	add	[struc_name],3
	call	move_data
	mov	al,3Ah
	stos	byte [edi]
	mov	ax,comment_marker
	stos	word [edi]
	mov	edi,ebx
	pop	esi
	add	esi,[edx+12]
	add	esi,3
	pop	edx
	jmp	use_macro
      struc_name_ok:
	mov	edx,[struc_name]
	movzx	eax,byte [edx-1]
	add	edx,eax
	push	edi
	lea	esi,[edi-1]
	mov	ecx,edi
	sub	ecx,edx
	std
	rep	movs byte [edi],[esi]
	cld
	pop	edi
	inc	edi
	mov	al,3Ah
	mov	[edx],al
	inc	al
	mov	[edx+1],al
	pop	esi edx
	inc	esi
	jmp	use_macro
      preprocess_label:
	dec	esi
	sub	esi,ecx
	lea	ebp,[esi-2]
	mov	ch,10b
	call	get_preprocessor_symbol
	jnc	symbolic_constant_in_label
	lea	esi,[esi+ecx+1]
	cmp	byte [esi],':'
	jne	preprocess_instruction
	inc	esi
	jmp	preprocess_instruction
      symbolic_constant_in_label:
	mov	ebx,[edx+8]
	mov	ecx,[edx+12]
	add	ecx,ebx
      check_for_broken_label:
	cmp	ebx,ecx
	je	label_broken
	cmp	byte [ebx],1Ah
	jne	label_broken
	movzx	eax,byte [ebx+1]
	lea	ebx,[ebx+2+eax]
	cmp	ebx,ecx
	je	label_constant_ok
	cmp	byte [ebx],':'
	jne	label_broken
	inc	ebx
	cmp	byte [ebx],':'
	jne	check_for_broken_label
	inc	ebx
	jmp	check_for_broken_label
      label_broken:
	push	line_preprocessed
	jmp	replace_symbolic_constant
      label_constant_ok:
	mov	ecx,edi
	sub	ecx,esi
	mov	edi,[edx+12]
	add	edi,ebp
	push	edi
	lea	eax,[edi+ecx]
	push	eax
	cmp	esi,edi
	je	replace_label
	jb	move_rest_of_line_up
	rep	movs byte [edi],[esi]
	jmp	replace_label
      move_rest_of_line_up:
	lea	esi,[esi+ecx-1]
	lea	edi,[edi+ecx-1]
	std
	rep	movs byte [edi],[esi]
	cld
      replace_label:
	mov	ecx,[edx+12]
	mov	edi,[esp+4]
	sub	edi,ecx
	mov	esi,[edx+8]
	rep	movs byte [edi],[esi]
	pop	edi esi
	inc	esi
	jmp	preprocess_instruction
      not_preprocessor_symbol:
	mov	esi,[current_offset]
	call	process_equ_constants
      line_preprocessed:
	pop	esi ecx
	ret
