use_instant_macro:
	push	edi [current_line] esi
	mov	eax,[error_line]
	mov	[current_line],eax
	mov	[macro_line],eax
	mov	esi,[instant_macro_start]
	cmp	[base_code],10h
	jae	do_match
	cmp	[base_code],0
	jne	do_irp
	call	precalculate_value
	cmp	eax,0
	jl	value_out_of_range
	push	[free_additional_memory]
	push	[macro_symbols]
	mov	[macro_symbols],0
	push	[counter_limit]
	mov	[struc_name],0
	mov	[counter_limit],eax
	lods	byte [esi]
	or	al,al
	jz	rept_counters_ok
	cmp	al,'{'
	je	rept_counters_ok
	cmp	al,1Ah
	jne	invalid_macro_arguments
      add_rept_counter:
	lods	byte [esi]
	movzx	ecx,al
	xor	eax,eax
	call	add_macro_symbol
	add	esi,ecx
	xor	eax,eax
	mov	dword [edx+12],eax
	inc	eax
	mov	dword [edx+8],eax
	lods	byte [esi]
	cmp	al,':'
	jne	rept_counter_added
	push	edx
	call	precalculate_value
	mov	edx,eax
	add	edx,[counter_limit]
	jo	value_out_of_range
	pop	edx
	mov	dword [edx+8],eax
	lods	byte [esi]
      rept_counter_added:
	cmp	al,','
	jne	rept_counters_ok
	lods	byte [esi]
	cmp	al,1Ah
	jne	invalid_macro_arguments
	jmp	add_rept_counter
      rept_counters_ok:
	dec	esi
	cmp	[counter_limit],0
	je	instant_macro_finish
      instant_macro_parameters_ok:
	xor	eax,eax
	call	process_macro
      instant_macro_finish:
	pop	[counter_limit]
	pop	[macro_symbols]
	pop	[free_additional_memory]
      instant_macro_done:
	pop	ebx esi edx
	cmp	byte [ebx],0
	je	line_preprocessed
	mov	[current_line],edi
	mov	ecx,4
	rep	movs dword [edi],[esi]
	test	[macro_status],0Fh
	jz	instant_macro_attached_line
	mov	ax,comment_marker
	stos	word [edi]
      instant_macro_attached_line:
	mov	esi,ebx
	sub	edx,ebx
	mov	ecx,edx
	call	move_data
	jmp	initial_preprocessing_ok
      precalculate_value:
	push	edi
	call	convert_expression
	mov	al,')'
	stosb
	push	esi
	mov	esi,[esp+4]
	mov	[error_line],0
	mov	[value_size],0
	call	calculate_expression
	cmp	[error_line],0
	je	value_precalculated
	jmp	[error]
      value_precalculated:
	mov	eax,[edi]
	mov	ecx,[edi+4]
	cdq
	cmp	edx,ecx
	jne	value_out_of_range
	cmp	dl,[edi+13]
	jne	value_out_of_range
	pop	esi edi
	ret
