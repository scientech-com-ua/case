# CaseTcl ASM package
# Copyright (c) 2016, Scientech LLC.
# All rights reserved.

assembler:
	xor	eax,eax
	mov	[stub_size],eax
	mov	[current_pass],ax
	mov	[resolver_flags],eax
	mov	[number_of_sections],eax
	mov	[actual_fixups_size],eax
      assembler_loop:
	mov	eax,[labels_list]
	mov	[tagged_blocks],eax
	mov	eax,[additional_memory]
	mov	[free_additional_memory],eax
	mov	eax,[additional_memory_end]
	mov	[structures_buffer],eax
	mov	esi,[source_start]
	mov	edi,[code_start]
	xor	eax,eax
	mov	dword [adjustment],eax
	mov	dword [adjustment+4],eax
	mov	[addressing_space],eax
	mov	[error_line],eax
	mov	[counter],eax
	mov	[format_flags],eax
	mov	[number_of_relocations],eax
	mov	[undefined_data_end],eax
	mov	[file_extension],eax
	mov	[next_pass_needed],al
	mov	[output_format],al
	mov	[adjustment_sign],al
	mov	[evex_mode],al
	mov	[code_type],16
	call	init_addressing_space
      pass_loop:
	call	assemble_line
	jnc	pass_loop
	mov	eax,[additional_memory_end]
	cmp	eax,[structures_buffer]
	je	pass_done
	sub	eax,18h
	mov	eax,[eax+4]
	mov	[current_line],eax
	jmp	missing_end_directive
      pass_done:
	call	close_pass
	mov	eax,[labels_list]
      check_symbols:
	cmp	eax,[memory_end]
	jae	symbols_checked
	test	byte [eax+8],8
	jz	symbol_defined_ok
	mov	cx,[current_pass]
	cmp	cx,[eax+18]
	jne	symbol_defined_ok
	test	byte [eax+8],1
	jz	symbol_defined_ok
	sub	cx,[eax+16]
	cmp	cx,1
	jne	symbol_defined_ok
	and	byte [eax+8],not 1
	or	[next_pass_needed],-1
      symbol_defined_ok:
	test	byte [eax+8],10h
	jz	use_prediction_ok
	mov	cx,[current_pass]
	and	byte [eax+8],not 10h
	test	byte [eax+8],20h
	jnz	check_use_prediction
	cmp	cx,[eax+18]
	jne	use_prediction_ok
	test	byte [eax+8],8
	jz	use_prediction_ok
	jmp	use_misprediction
      check_use_prediction:
	test	byte [eax+8],8
	jz	use_misprediction
	cmp	cx,[eax+18]
	je	use_prediction_ok
      use_misprediction:
	or	[next_pass_needed],-1
      use_prediction_ok:
	test	byte [eax+8],40h
	jz	check_next_symbol
	and	byte [eax+8],not 40h
	test	byte [eax+8],4
	jnz	define_misprediction
	mov	cx,[current_pass]
	test	byte [eax+8],80h
	jnz	check_define_prediction
	cmp	cx,[eax+16]
	jne	check_next_symbol
	test	byte [eax+8],1
	jz	check_next_symbol
	jmp	define_misprediction
      check_define_prediction:
	test	byte [eax+8],1
	jz	define_misprediction
	cmp	cx,[eax+16]
	je	check_next_symbol
      define_misprediction:
	or	[next_pass_needed],-1
      check_next_symbol:
	add	eax,LABEL_STRUCTURE_SIZE
	jmp	check_symbols
      symbols_checked:
	cmp	[next_pass_needed],0
	jne	next_pass
	mov	eax,[error_line]
	or	eax,eax
	jz	assemble_ok
	mov	[current_line],eax
	cmp	[error],undefined_symbol
	jne	error_confirmed
	mov	eax,[error_info]
	or	eax,eax
	jz	error_confirmed
	test	byte [eax+8],1
	jnz	next_pass
      error_confirmed:
	call	error_handler
      error_handler:
	mov	eax,[error]
	sub	eax,error_handler
	add	[esp],eax
	ret
      next_pass:
	inc	[current_pass]
	mov	ax,[current_pass]
	cmp	ax,[passes_limit]
	je	code_cannot_be_generated
	jmp	assembler_loop
      assemble_ok:
	ret

create_addressing_space:
	mov	ebx,[addressing_space]
	test	ebx,ebx
	jz	init_addressing_space
	test	byte [ebx+0Ah],1
	jnz	illegal_instruction
	mov	eax,edi
	sub	eax,[ebx+18h]
	mov	[ebx+1Ch],eax
      init_addressing_space:
	mov	ebx,[tagged_blocks]
	mov	dword [ebx-4],10h
	mov	dword [ebx-8],20h
	sub	ebx,8+20h
	cmp	ebx,edi
	jbe	out_of_memory
	mov	[tagged_blocks],ebx
	mov	[addressing_space],ebx
	xor	eax,eax
	mov	[ebx],edi
	mov	[ebx+4],eax
	mov	[ebx+8],eax
	mov	[ebx+10h],eax
	mov	[ebx+14h],eax
	mov	[ebx+18h],edi
	mov	[ebx+1Ch],eax
	ret

assemble_line:
	mov	eax,[tagged_blocks]
	sub	eax,100h
	cmp	edi,eax
	ja	out_of_memory
	lods	byte [esi]
	cmp	al,1
	je	assemble_instruction
	jb	source_end
	cmp	al,3
	jb	define_label
	je	define_constant
	cmp	al,4
	je	label_addressing_space
	cmp	al,0Fh
	je	new_line
	cmp	al,13h
	je	code_type_setting
	cmp	al,10h
	jne	illegal_instruction
	lods	byte [esi]
	jmp	segment_prefix
      code_type_setting:
	lods	byte [esi]
	mov	[code_type],al
	jmp	instruction_assembled
      new_line:
	lods	dword [esi]
	mov	[current_line],eax
	and	[prefix_flags],0
	cmp	[symbols_file],0
	je	continue_line
	cmp	[next_pass_needed],0
	jne	continue_line
	mov	ebx,[tagged_blocks]
	mov	dword [ebx-4],1
	mov	dword [ebx-8],14h
	sub	ebx,8+14h
	cmp	ebx,edi
	jbe	out_of_memory
	mov	[tagged_blocks],ebx
	mov	[ebx],eax
	mov	[ebx+4],edi
	mov	eax,[addressing_space]
	mov	[ebx+8],eax
	mov	al,[code_type]
	mov	[ebx+10h],al
      continue_line:
	cmp	byte [esi],0Fh
	je	line_assembled
	jmp	assemble_line
      define_label:
	lods	dword [esi]
	cmp	eax,0Fh
	jb	invalid_use_of_symbol
	je	reserved_word_used_as_symbol
	mov	ebx,eax
	lods	byte [esi]
	mov	[label_size],al
	call	make_label
	jmp	continue_line
      make_label:
	mov	eax,edi
	xor	edx,edx
	xor	cl,cl
	mov	ebp,[addressing_space]
	sub	eax,[ds:ebp]
	sbb	edx,[ds:ebp+4]
	sbb	cl,[ds:ebp+8]
	jp	label_value_ok
	call	recoverable_overflow
      label_value_ok:
	mov	[address_sign],cl
	test	byte [ds:ebp+0Ah],1
	jnz	make_virtual_label
	or	byte [ebx+9],1
	xchg	eax,[ebx]
	xchg	edx,[ebx+4]
	mov	ch,[ebx+9]
	shr	ch,1
	and	ch,1
	neg	ch
	sub	eax,[ebx]
	sbb	edx,[ebx+4]
	sbb	ch,cl
	mov	dword [adjustment],eax
	mov	dword [adjustment+4],edx
	mov	[adjustment_sign],ch
	or	al,ch
	or	eax,edx
	setnz	ah
	jmp	finish_label
      make_virtual_label:
	and	byte [ebx+9],not 1
	cmp	eax,[ebx]
	mov	[ebx],eax
	setne	ah
	cmp	edx,[ebx+4]
	mov	[ebx+4],edx
	setne	al
	or	ah,al
      finish_label:
	mov	ebp,[addressing_space]
	mov	ch,[ds:ebp+9]
	mov	cl,[label_size]
	mov	edx,[ds:ebp+14h]
	mov	ebp,[ds:ebp+10h]
      finish_label_symbol:
	mov	al,[address_sign]
	xor	al,[ebx+9]
	and	al,10b
	or	ah,al
	xor	[ebx+9],al
	cmp	cl,[ebx+10]
	mov	[ebx+10],cl
	setne	al
	or	ah,al
	cmp	ch,[ebx+11]
	mov	[ebx+11],ch
	setne	al
	or	ah,al
	cmp	ebp,[ebx+12]
	mov	[ebx+12],ebp
	setne	al
	or	ah,al
	or	ch,ch
	jz	label_symbol_ok
	cmp	edx,[ebx+20]
	mov	[ebx+20],edx
	setne	al
	or	ah,al
      label_symbol_ok:
	mov	cx,[current_pass]
	xchg	[ebx+16],cx
	mov	edx,[current_line]
	mov	[ebx+28],edx
	and	byte [ebx+8],not 2
	test	byte [ebx+8],1
	jz	new_label
	cmp	cx,[ebx+16]
	je	symbol_already_defined
	btr	dword [ebx+8],10
	jc	requalified_label
	inc	cx
	sub	cx,[ebx+16]
	setnz	al
	or	ah,al
	jz	label_made
	test	byte [ebx+8],8
	jz	label_made
	mov	cx,[current_pass]
	cmp	cx,[ebx+18]
	jne	label_made
      requalified_label:
	or	[next_pass_needed],-1
      label_made:
	ret
      new_label:
	or	byte [ebx+8],1
	ret
      define_constant:
	lods	dword [esi]
	inc	esi
	cmp	eax,0Fh
	jb	invalid_use_of_symbol
	je	reserved_word_used_as_symbol
	push	eax
	or	[operand_flags],1
	call	get_value
	pop	ebx
	xor	cl,cl
	mov	ch,[value_type]
	cmp	ch,3
	je	invalid_use_of_symbol
      make_constant:
	and	byte [ebx+9],not 1
	cmp	eax,[ebx]
	mov	[ebx],eax
	setne	ah
	cmp	edx,[ebx+4]
	mov	[ebx+4],edx
	setne	al
	or	ah,al
	mov	al,[value_sign]
	xor	al,[ebx+9]
	and	al,10b
	or	ah,al
	xor	[ebx+9],al
	cmp	cl,[ebx+10]
	mov	[ebx+10],cl
	setne	al
	or	ah,al
	cmp	ch,[ebx+11]
	mov	[ebx+11],ch
	setne	al
	or	ah,al
	xor	edx,edx
	cmp	edx,[ebx+12]
	mov	[ebx+12],edx
	setne	al
	or	ah,al
	or	ch,ch
	jz	constant_symbol_ok
	mov	edx,[symbol_identifier]
	cmp	edx,[ebx+20]
	mov	[ebx+20],edx
	setne	al
	or	ah,al
      constant_symbol_ok:
	mov	cx,[current_pass]
	xchg	[ebx+16],cx
	mov	edx,[current_line]
	mov	[ebx+28],edx
	test	byte [ebx+8],1
	jz	new_constant
	cmp	cx,[ebx+16]
	jne	redeclare_constant
	test	byte [ebx+8],2
	jz	symbol_already_defined
	or	byte [ebx+8],4
	and	byte [ebx+9],not 4
	jmp	instruction_assembled
      redeclare_constant:
	btr	dword [ebx+8],10
	jc	requalified_constant
	inc	cx
	sub	cx,[ebx+16]
	setnz	al
	or	ah,al
	jz	instruction_assembled
	test	byte [ebx+8],4
	jnz	instruction_assembled
	test	byte [ebx+8],8
	jz	instruction_assembled
	mov	cx,[current_pass]
	cmp	cx,[ebx+18]
	jne	instruction_assembled
      requalified_constant:
	or	[next_pass_needed],-1
	jmp	instruction_assembled
      new_constant:
	or	byte [ebx+8],1+2
	jmp	instruction_assembled
      label_addressing_space:
	lods	dword [esi]
	cmp	eax,0Fh
	jb	invalid_use_of_symbol
	je	reserved_word_used_as_symbol
	mov	cx,[current_pass]
	test	byte [eax+8],1
	jz	make_addressing_space_label
	cmp	cx,[eax+16]
	je	symbol_already_defined
	test	byte [eax+9],4
	jnz	make_addressing_space_label
	or	[next_pass_needed],-1
      make_addressing_space_label:
	mov	dx,[eax+8]
	and	dx,not (2 or 100h)
	or	dx,1 or 4 or 400h
	mov	[eax+8],dx
	mov	[eax+16],cx
	mov	edx,[current_line]
	mov	[eax+28],edx
	mov	ebx,[addressing_space]
	mov	[eax],ebx
	or	byte [ebx+0Ah],2
	jmp	continue_line
      assemble_instruction:
#	 mov	 [operand_size],0
#	 mov	 [operand_flags],0
#	 mov	 [operand_prefix],0
#	 mov	 [rex_prefix],0
	and	dword [operand_size],0
#	 mov	 [opcode_prefix],0
#	 mov	 [vex_required],0
#	 mov	 [vex_register],0
#	 mov	 [immediate_size],0
	and	dword [opcode_prefix],0
	call	instruction_handler
      instruction_handler:
	movzx	ebx,word [esi]
	mov	al,[esi+2]
	add	esi,3
	add	[esp],ebx
	ret
      instruction_assembled:
	test	[prefix_flags],not 1
	jnz	illegal_instruction
	mov	al,[esi]
	cmp	al,0Fh
	je	line_assembled
	or	al,al
	jnz	extra_characters_on_line
      line_assembled:
	clc
	ret
      source_end:
	dec	esi
	stc
	ret

org_directive:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_qword_value
	mov	cl,[value_type]
	test	cl,1
	jnz	invalid_use_of_symbol
	push	eax
	mov	ebx,[addressing_space]
	mov	eax,edi
	sub	eax,[ebx+18h]
	mov	[ebx+1Ch],eax
	test	byte [ebx+0Ah],1
	jnz	in_virtual
	call	init_addressing_space
	jmp	org_space_ok
      in_virtual:
	call	close_virtual_addressing_space
	call	init_addressing_space
	or	byte [ebx+0Ah],1
      org_space_ok:
	pop	eax
	mov	[ebx+9],cl
	mov	cl,[value_sign]
	sub	[ebx],eax
	sbb	[ebx+4],edx
	sbb	byte [ebx+8],cl
	jp	org_value_ok
	call	recoverable_overflow
      org_value_ok:
	mov	edx,[symbol_identifier]
	mov	[ebx+14h],edx
	cmp	[output_format],1
	ja	instruction_assembled
	cmp	edi,[code_start]
	jne	instruction_assembled
	cmp	eax,100h
	jne	instruction_assembled
	bts	[format_flags],0
	jmp	instruction_assembled
label_directive:
	lods	byte [esi]
	cmp	al,2
	jne	invalid_argument
	lods	dword [esi]
	cmp	eax,0Fh
	jb	invalid_use_of_symbol
	je	reserved_word_used_as_symbol
	inc	esi
	mov	ebx,eax
	mov	[label_size],0
	lods	byte [esi]
	cmp	al,':'
	je	get_label_size
	dec	esi
	cmp	al,11h
	jne	label_size_ok
      get_label_size:
	lods	word [esi]
	cmp	al,11h
	jne	invalid_argument
	mov	[label_size],ah
      label_size_ok:
	cmp	byte [esi],80h
	je	get_free_label_value
	call	make_label
	jmp	instruction_assembled
      get_free_label_value:
	inc	esi
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	push	ebx ecx
	or	byte [ebx+8],4
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_address_value
	or	bh,bh
	setnz	ch
	xchg	ch,cl
	mov	bp,cx
	shl	ebp,16
	xchg	bl,bh
	mov	bp,bx
	pop	ecx ebx
	and	byte [ebx+8],not 4
	mov	ch,[value_type]
	test	ch,1
	jnz	invalid_use_of_symbol
      make_free_label:
	and	byte [ebx+9],not 1
	cmp	eax,[ebx]
	mov	[ebx],eax
	setne	ah
	cmp	edx,[ebx+4]
	mov	[ebx+4],edx
	setne	al
	or	ah,al
	mov	edx,[address_symbol]
	mov	cl,[label_size]
	call	finish_label_symbol
	jmp	instruction_assembled
load_directive:
	lods	byte [esi]
	cmp	al,2
	jne	invalid_argument
	lods	dword [esi]
	cmp	eax,0Fh
	jb	invalid_use_of_symbol
	je	reserved_word_used_as_symbol
	inc	esi
	push	eax
	mov	al,1
	cmp	byte [esi],11h
	jne	load_size_ok
	lods	byte [esi]
	lods	byte [esi]
      load_size_ok:
	cmp	al,8
	ja	invalid_value
	mov	[operand_size],al
	and	dword [value],0
	and	dword [value+4],0
	lods	byte [esi]
	cmp	al,82h
	jne	invalid_argument
	call	get_data_point
	jc	value_loaded
	push	esi edi
	mov	esi,ebx
	mov	edi,value
	rep	movs byte [edi],[esi]
	pop	edi esi
      value_loaded:
	mov	[value_sign],0
	mov	eax,dword [value]
	mov	edx,dword [value+4]
	pop	ebx
	xor	cx,cx
	jmp	make_constant
      get_data_point:
	mov	ebx,[addressing_space]
	mov	ecx,edi
	sub	ecx,[ebx+18h]
	mov	[ebx+1Ch],ecx
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],11h
	jne	get_data_address
	cmp	word [esi+1+4],'):'
	jne	get_data_address
	inc	esi
	lods	dword [esi]
	add	esi,2
	cmp	byte [esi],'('
	jne	invalid_argument
	inc	esi
	cmp	eax,0Fh
	jbe	reserved_word_used_as_symbol
	mov	edx,undefined_symbol
	test	byte [eax+8],1
	jz	addressing_space_unavailable
	mov	edx,symbol_out_of_scope
	mov	cx,[eax+16]
	cmp	cx,[current_pass]
	jne	addressing_space_unavailable
	test	byte [eax+9],4
	jz	invalid_use_of_symbol
	mov	ebx,eax
	mov	ax,[current_pass]
	mov	[ebx+18],ax
	or	byte [ebx+8],8
	cmp	[symbols_file],0
	je	get_addressing_space
	cmp	[next_pass_needed],0
	jne	get_addressing_space
	call	store_label_reference
      get_addressing_space:
	mov	ebx,[ebx]
      get_data_address:
	push	ebx
	cmp	byte [esi],'.'
	je	invalid_value
	or	[operand_flags],1
	call	get_address_value
	pop	ebp
	call	calculate_relative_offset
	cmp	[next_pass_needed],0
	jne	data_address_type_ok
	cmp	[value_type],0
	jne	invalid_use_of_symbol
      data_address_type_ok:
	mov	ebx,edi
	xor	ecx,ecx
	add	ebx,eax
	adc	edx,ecx
	mov	eax,ebx
	sub	eax,[ds:ebp+18h]
	sbb	edx,ecx
	jnz	bad_data_address
	mov	cl,[operand_size]
	add	eax,ecx
	cmp	eax,[ds:ebp+1Ch]
	ja	bad_data_address
	clc
	ret
      addressing_space_unavailable:
	cmp	[error_line],0
	jne	get_data_address
	push	[current_line]
	pop	[error_line]
	mov	[error],edx
	mov	[error_info],eax
	jmp	get_data_address
      bad_data_address:
	call	recoverable_overflow
	stc
	ret
store_directive:
	cmp	byte [esi],11h
	je	sized_store
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	call	get_byte_value
	xor	edx,edx
	movzx	eax,al
	mov	[operand_size],1
	jmp	store_value_ok
      sized_store:
	or	[operand_flags],1
	call	get_value
      store_value_ok:
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	dword [value],eax
	mov	dword [value+4],edx
	lods	byte [esi]
	cmp	al,80h
	jne	invalid_argument
	call	get_data_point
	jc	instruction_assembled
	push	esi edi
	mov	esi,value
	mov	edi,ebx
	rep	movs byte [edi],[esi]
	mov	eax,edi
	pop	edi esi
	cmp	ebx,[undefined_data_end]
	jae	instruction_assembled
	cmp	eax,[undefined_data_start]
	jbe	instruction_assembled
	mov	[undefined_data_start],eax
	jmp	instruction_assembled

display_directive:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],0
	jne	display_byte
	inc	esi
	lods	dword [esi]
	mov	ecx,eax
	push	edi
	mov	edi,[tagged_blocks]
	sub	edi,8
	sub	edi,eax
	cmp	edi,[esp]
	jbe	out_of_memory
	mov	[tagged_blocks],edi
	rep	movs byte [edi],[esi]
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	pop	edi
	inc	esi
	jmp	display_next
      display_byte:
	call	get_byte_value
	push	edi
	mov	edi,[tagged_blocks]
	sub	edi,8+1
	mov	[tagged_blocks],edi
	stos	byte [edi]
	mov	eax,1
	stos	dword [edi]
	dec	eax
	stos	dword [edi]
	pop	edi
      display_next:
	cmp	edi,[tagged_blocks]
	ja	out_of_memory
	lods	byte [esi]
	cmp	al,','
	je	display_directive
	dec	esi
	jmp	instruction_assembled
show_display_buffer:
	mov	eax,[tagged_blocks]
	or	eax,eax
	jz	display_done
	mov	esi,[labels_list]
	cmp	esi,eax
	je	display_done
      display_messages:
	sub	esi,8
	mov	eax,[esi+4]
	mov	ecx,[esi]
	sub	esi,ecx
	test	eax,eax
	jnz	skip_block
	push	esi
	call	display_block
	pop	esi
      skip_block:
	cmp	esi,[tagged_blocks]
	jne	display_messages
      display_done:
	ret

times_directive:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	cmp	eax,0
	je	zero_times
	cmp	byte [esi],':'
	jne	times_argument_ok
	inc	esi
      times_argument_ok:
	push	[counter]
	push	[counter_limit]
	mov	[counter_limit],eax
	mov	[counter],1
      times_loop:
	mov	eax,esp
	sub	eax,100h
	jc	stack_overflow
	cmp	eax,[stack_limit]
	jb	stack_overflow
	push	esi
	or	[prefix_flags],1
	call	continue_line
	mov	eax,[counter_limit]
	cmp	[counter],eax
	je	times_done
	inc	[counter]
	pop	esi
	jmp	times_loop
      times_done:
	pop	eax
	pop	[counter_limit]
	pop	[counter]
	jmp	instruction_assembled
      zero_times:
	call	skip_symbol
	jnc	zero_times
	jmp	instruction_assembled

virtual_directive:
	lods	byte [esi]
	cmp	al,80h
	jne	virtual_at_current
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_address_value
	mov	ebp,[address_symbol]
	or	bh,bh
	setnz	ch
	jmp	set_virtual
      virtual_at_current:
	dec	esi
	mov	ebp,[addressing_space]
	mov	al,[ds:ebp+9]
	mov	[value_type],al
	mov	eax,edi
	xor	edx,edx
	xor	cl,cl
	sub	eax,[ds:ebp]
	sbb	edx,[ds:ebp+4]
	sbb	cl,[ds:ebp+8]
	mov	[address_sign],cl
	mov	bx,[ds:ebp+10h]
	mov	cx,[ds:ebp+10h+2]
	xchg	bh,bl
	xchg	ch,cl
	mov	ebp,[ds:ebp+14h]
      set_virtual:
	xchg	bl,bh
	xchg	cl,ch
	shl	ecx,16
	mov	cx,bx
	push	ecx eax
	call	allocate_structure_data
	mov	word [ebx],virtual_directive-instruction_handler
	mov	ecx,[addressing_space]
	mov	[ebx+12],ecx
	mov	[ebx+8],edi
	mov	ecx,[current_line]
	mov	[ebx+4],ecx
	mov	ebx,[addressing_space]
	mov	eax,edi
	sub	eax,[ebx+18h]
	mov	[ebx+1Ch],eax
	call	init_addressing_space
	or	byte [ebx+0Ah],1
	pop	eax
	mov	cl,[address_sign]
	not	eax
	not	edx
	not	cl
	add	eax,1
	adc	edx,0
	adc	cl,0
	add	eax,edi
	adc	edx,0
	adc	cl,0
	mov	[ebx],eax
	mov	[ebx+4],edx
	mov	[ebx+8],cl
	pop	dword [ebx+10h]
	mov	[ebx+14h],ebp
	mov	al,[value_type]
	test	al,1
	jnz	invalid_use_of_symbol
	mov	[ebx+9],al
	jmp	instruction_assembled
      allocate_structure_data:
	mov	ebx,[structures_buffer]
	sub	ebx,18h
	cmp	ebx,[free_additional_memory]
	jb	out_of_memory
	mov	[structures_buffer],ebx
	ret
      find_structure_data:
	mov	ebx,[structures_buffer]
      scan_structures:
	cmp	ebx,[additional_memory_end]
	je	no_such_structure
	cmp	ax,[ebx]
	je	structure_data_found
	add	ebx,18h
	jmp	scan_structures
      structure_data_found:
	ret
      no_such_structure:
	stc
	ret
      end_virtual:
	call	find_structure_data
	jc	unexpected_instruction
	push	ebx
	call	close_virtual_addressing_space
	pop	ebx
	mov	eax,[ebx+12]
	mov	[addressing_space],eax
	mov	edi,[ebx+8]
      remove_structure_data:
	push	esi edi
	mov	ecx,ebx
	sub	ecx,[structures_buffer]
	shr	ecx,2
	lea	esi,[ebx-4]
	lea	edi,[esi+18h]
	std
	rep	movs dword [edi],[esi]
	cld
	add	[structures_buffer],18h
	pop	edi esi
	ret
      close_virtual_addressing_space:
	mov	ebx,[addressing_space]
	mov	eax,edi
	sub	eax,[ebx+18h]
	mov	[ebx+1Ch],eax
	test	byte [ebx+0Ah],2
	jz	addressing_space_closed
	push	esi edi ecx edx
	mov	ecx,eax
	mov	eax,[tagged_blocks]
	mov	dword [eax-4],11h
	mov	dword [eax-8],ecx
	sub	eax,8
	sub	eax,ecx
	mov	[tagged_blocks],eax
	lea	edi,[eax+ecx-1]
	xchg	eax,[ebx+18h]
	lea	esi,[eax+ecx-1]
	mov	eax,edi
	sub	eax,esi
	std
	shr	ecx,1
	jnc	virtual_byte_ok
	movs	byte [edi],[esi]
      virtual_byte_ok:
	dec	esi
	dec	edi
	shr	ecx,1
	jnc	virtual_word_ok
	movs	word [edi],[esi]
      virtual_word_ok:
	sub	esi,2
	sub	edi,2
	rep	movs dword [edi],[esi]
	cld
	xor	edx,edx
	add	[ebx],eax
	adc	dword [ebx+4],edx
	adc	byte [ebx+8],dl
	pop	edx ecx edi esi
      addressing_space_closed:
	ret
repeat_directive:
	test	[prefix_flags],1
	jnz	unexpected_instruction
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	cmp	eax,0
	je	zero_repeat
	call	allocate_structure_data
	mov	word [ebx],repeat_directive-instruction_handler
	xchg	eax,[counter_limit]
	mov	[ebx+10h],eax
	mov	eax,1
	xchg	eax,[counter]
	mov	[ebx+14h],eax
	mov	[ebx+8],esi
	mov	eax,[current_line]
	mov	[ebx+4],eax
	jmp	instruction_assembled
      end_repeat:
	test	[prefix_flags],1
	jnz	unexpected_instruction
	call	find_structure_data
	jc	unexpected_instruction
	mov	eax,[counter_limit]
	inc	[counter]
	cmp	[counter],eax
	jbe	continue_repeating
      stop_repeat:
	mov	eax,[ebx+10h]
	mov	[counter_limit],eax
	mov	eax,[ebx+14h]
	mov	[counter],eax
	call	remove_structure_data
	jmp	instruction_assembled
      continue_repeating:
	mov	esi,[ebx+8]
	jmp	instruction_assembled
      zero_repeat:
	mov	al,[esi]
	or	al,al
	jz	missing_end_directive
	cmp	al,0Fh
	jne	extra_characters_on_line
	call	find_end_repeat
	jmp	instruction_assembled
      find_end_repeat:
	call	find_structure_end
	cmp	ax,repeat_directive-instruction_handler
	jne	unexpected_instruction
	ret
while_directive:
	test	[prefix_flags],1
	jnz	unexpected_instruction
	call	allocate_structure_data
	mov	word [ebx],while_directive-instruction_handler
	mov	eax,1
	xchg	eax,[counter]
	mov	[ebx+10h],eax
	mov	[ebx+8],esi
	mov	eax,[current_line]
	mov	[ebx+4],eax
      do_while:
	push	ebx
	call	calculate_logical_expression
	or	al,al
	jnz	while_true
	mov	al,[esi]
	or	al,al
	jz	missing_end_directive
	cmp	al,0Fh
	jne	extra_characters_on_line
      stop_while:
	call	find_end_while
	pop	ebx
	mov	eax,[ebx+10h]
	mov	[counter],eax
	call	remove_structure_data
	jmp	instruction_assembled
      while_true:
	pop	ebx
	jmp	instruction_assembled
      end_while:
	test	[prefix_flags],1
	jnz	unexpected_instruction
	call	find_structure_data
	jc	unexpected_instruction
	mov	eax,[ebx+4]
	mov	[current_line],eax
	inc	[counter]
	jz	too_many_repeats
	mov	esi,[ebx+8]
	jmp	do_while
      find_end_while:
	call	find_structure_end
	cmp	ax,while_directive-instruction_handler
	jne	unexpected_instruction
	ret
if_directive:
	test	[prefix_flags],1
	jnz	unexpected_instruction
	call	calculate_logical_expression
	mov	dl,al
	mov	al,[esi]
	or	al,al
	jz	missing_end_directive
	cmp	al,0Fh
	jne	extra_characters_on_line
	or	dl,dl
	jnz	if_true
	call	find_else
	jc	instruction_assembled
	mov	al,[esi]
	cmp	al,1
	jne	else_true
	cmp	word [esi+1],if_directive-instruction_handler
	jne	else_true
	add	esi,4
	jmp	if_directive
      if_true:
	xor	al,al
      make_if_structure:
	call	allocate_structure_data
	mov	word [ebx],if_directive-instruction_handler
	mov	byte [ebx+2],al
	mov	eax,[current_line]
	mov	[ebx+4],eax
	jmp	instruction_assembled
      else_true:
	or	al,al
	jz	missing_end_directive
	cmp	al,0Fh
	jne	extra_characters_on_line
	or	al,-1
	jmp	make_if_structure
      else_directive:
	test	[prefix_flags],1
	jnz	unexpected_instruction
	mov	ax,if_directive-instruction_handler
	call	find_structure_data
	jc	unexpected_instruction
	cmp	byte [ebx+2],0
	jne	unexpected_instruction
      found_else:
	mov	al,[esi]
	cmp	al,1
	jne	skip_else
	cmp	word [esi+1],if_directive-instruction_handler
	jne	skip_else
	add	esi,4
	call	find_else
	jnc	found_else
	call	remove_structure_data
	jmp	instruction_assembled
      skip_else:
	or	al,al
	jz	missing_end_directive
	cmp	al,0Fh
	jne	extra_characters_on_line
	call	find_end_if
	call	remove_structure_data
	jmp	instruction_assembled
      end_if:
	test	[prefix_flags],1
	jnz	unexpected_instruction
	call	find_structure_data
	jc	unexpected_instruction
	call	remove_structure_data
	jmp	instruction_assembled
      find_else:
	call	find_structure_end
	cmp	ax,else_directive-instruction_handler
	je	else_found
	cmp	ax,if_directive-instruction_handler
	jne	unexpected_instruction
	stc
	ret
      else_found:
	clc
	ret
      find_end_if:
	call	find_structure_end
	cmp	ax,if_directive-instruction_handler
	jne	unexpected_instruction
	ret
      find_structure_end:
	push	[error_line]
	mov	eax,[current_line]
	mov	[error_line],eax
      find_end_directive:
	call	skip_symbol
	jnc	find_end_directive
	lods	byte [esi]
	cmp	al,0Fh
	jne	no_end_directive
	lods	dword [esi]
	mov	[current_line],eax
      skip_labels:
	cmp	byte [esi],2
	jne	labels_ok
	add	esi,6
	jmp	skip_labels
      labels_ok:
	cmp	byte [esi],1
	jne	find_end_directive
	mov	ax,[esi+1]
	cmp	ax,prefix_instruction-instruction_handler
	je	find_end_directive
	add	esi,4
	cmp	ax,repeat_directive-instruction_handler
	je	skip_repeat
	cmp	ax,while_directive-instruction_handler
	je	skip_while
	cmp	ax,if_directive-instruction_handler
	je	skip_if
	cmp	ax,else_directive-instruction_handler
	je	structure_end
	cmp	ax,end_directive-instruction_handler
	jne	find_end_directive
	cmp	byte [esi],1
	jne	find_end_directive
	mov	ax,[esi+1]
	add	esi,4
	cmp	ax,repeat_directive-instruction_handler
	je	structure_end
	cmp	ax,while_directive-instruction_handler
	je	structure_end
	cmp	ax,if_directive-instruction_handler
	jne	find_end_directive
      structure_end:
	pop	[error_line]
	ret
      no_end_directive:
	mov	eax,[error_line]
	mov	[current_line],eax
	jmp	missing_end_directive
      skip_repeat:
	call	find_end_repeat
	jmp	find_end_directive
      skip_while:
	call	find_end_while
	jmp	find_end_directive
      skip_if:
	call	skip_if_block
	jmp	find_end_directive
      skip_if_block:
	call	find_else
	jc	if_block_skipped
	cmp	byte [esi],1
	jne	skip_after_else
	cmp	word [esi+1],if_directive-instruction_handler
	jne	skip_after_else
	add	esi,4
	jmp	skip_if_block
      skip_after_else:
	call	find_end_if
      if_block_skipped:
	ret
end_directive:
	lods	byte [esi]
	cmp	al,1
	jne	invalid_argument
	lods	word [esi]
	inc	esi
	cmp	ax,virtual_directive-instruction_handler
	je	end_virtual
	cmp	ax,repeat_directive-instruction_handler
	je	end_repeat
	cmp	ax,while_directive-instruction_handler
	je	end_while
	cmp	ax,if_directive-instruction_handler
	je	end_if
	cmp	ax,data_directive-instruction_handler
	je	end_data
	jmp	invalid_argument
break_directive:
	mov	ebx,[structures_buffer]
	mov	al,[esi]
	or	al,al
	jz	find_breakable_structure
	cmp	al,0Fh
	jne	extra_characters_on_line
      find_breakable_structure:
	cmp	ebx,[additional_memory_end]
	je	unexpected_instruction
	mov	ax,[ebx]
	cmp	ax,repeat_directive-instruction_handler
	je	break_repeat
	cmp	ax,while_directive-instruction_handler
	je	break_while
	cmp	ax,if_directive-instruction_handler
	je	break_if
	add	ebx,18h
	jmp	find_breakable_structure
      break_if:
	push	[current_line]
	mov	eax,[ebx+4]
	mov	[current_line],eax
	call	remove_structure_data
	call	skip_if_block
	pop	[current_line]
	mov	ebx,[structures_buffer]
	jmp	find_breakable_structure
      break_repeat:
	push	ebx
	call	find_end_repeat
	pop	ebx
	jmp	stop_repeat
      break_while:
	push	ebx
	jmp	stop_while

data_bytes:
	call	define_data
	lods	byte [esi]
	cmp	al,'('
	je	get_byte
	cmp	al,'?'
	jne	invalid_argument
	mov	eax,edi
	mov	byte [edi],0
	inc	edi
	jmp	undefined_data
      get_byte:
	cmp	byte [esi],0
	je	get_string
	call	get_byte_value
	stos	byte [edi]
	ret
      get_string:
	inc	esi
	lods	dword [esi]
	mov	ecx,eax
	lea	eax,[edi+ecx]
	cmp	eax,[tagged_blocks]
	ja	out_of_memory
	rep	movs byte [edi],[esi]
	inc	esi
	ret
      undefined_data:
	mov	ebp,[addressing_space]
	test	byte [ds:ebp+0Ah],1
	jz	mark_undefined_data
	ret
      mark_undefined_data:
	cmp	eax,[undefined_data_end]
	je	undefined_data_ok
	mov	[undefined_data_start],eax
      undefined_data_ok:
	mov	[undefined_data_end],edi
	ret
      define_data:
	cmp	edi,[tagged_blocks]
	jae	out_of_memory
	cmp	byte [esi],'('
	jne	simple_data_value
	mov	ebx,esi
	inc	esi
	call	skip_expression
	xchg	esi,ebx
	cmp	byte [ebx],81h
	jne	simple_data_value
	inc	esi
	call	get_count_value
	inc	esi
	or	eax,eax
	jz	duplicate_zero_times
	cmp	byte [esi],91h
	jne	duplicate_single_data_value
	inc	esi
      duplicate_data:
	push	eax esi
      duplicated_values:
	cmp	edi,[tagged_blocks]
	jae	out_of_memory
	call	near dword [esp+8]
	lods	byte [esi]
	cmp	al,','
	je	duplicated_values
	cmp	al,92h
	jne	invalid_argument
	pop	ebx eax
	dec	eax
	jz	data_defined
	mov	esi,ebx
	jmp	duplicate_data
      duplicate_single_data_value:
	cmp	edi,[tagged_blocks]
	jae	out_of_memory
	push	eax esi
	call	near dword [esp+8]
	pop	ebx eax
	dec	eax
	jz	data_defined
	mov	esi,ebx
	jmp	duplicate_single_data_value
      duplicate_zero_times:
	cmp	byte [esi],91h
	jne	skip_single_data_value
	inc	esi
      skip_data_value:
	call	skip_symbol
	jc	invalid_argument
	cmp	byte [esi],92h
	jne	skip_data_value
	inc	esi
	jmp	data_defined
      skip_single_data_value:
	call	skip_symbol
	jmp	data_defined
      simple_data_value:
	cmp	edi,[tagged_blocks]
	jae	out_of_memory
	call	near dword [esp]
      data_defined:
	lods	byte [esi]
	cmp	al,','
	je	define_data
	dec	esi
	add	esp,4
	jmp	instruction_assembled
data_unicode:
	or	[base_code],-1
	jmp	define_words
data_words:
	mov	[base_code],0
      define_words:
	call	define_data
	lods	byte [esi]
	cmp	al,'('
	je	get_word
	cmp	al,'?'
	jne	invalid_argument
	mov	eax,edi
	and	word [edi],0
	scas	word [edi]
	jmp	undefined_data
	ret
      get_word:
	cmp	[base_code],0
	je	word_data_value
	cmp	byte [esi],0
	je	word_string
      word_data_value:
	call	get_word_value
	call	mark_relocation
	stos	word [edi]
	ret
      word_string:
	inc	esi
	lods	dword [esi]
	mov	ecx,eax
	jecxz	word_string_ok
	lea	eax,[edi+ecx*2]
	cmp	eax,[tagged_blocks]
	ja	out_of_memory
	xor	ah,ah
      copy_word_string:
	lods	byte [esi]
	stos	word [edi]
	loop	copy_word_string
      word_string_ok:
	inc	esi
	ret
data_dwords:
	call	define_data
	lods	byte [esi]
	cmp	al,'('
	je	get_dword
	cmp	al,'?'
	jne	invalid_argument
	mov	eax,edi
	and	dword [edi],0
	scas	dword [edi]
	jmp	undefined_data
      get_dword:
	push	esi
	call	get_dword_value
	pop	ebx
	cmp	byte [esi],':'
	je	complex_dword
	call	mark_relocation
	stos	dword [edi]
	ret
      complex_dword:
	mov	esi,ebx
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_word_value
	push	eax
	inc	esi
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_operand
	mov	al,[value_type]
	push	eax
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_word_value
	call	mark_relocation
	stos	word [edi]
	pop	eax
	mov	[value_type],al
	pop	eax
	call	mark_relocation
	stos	word [edi]
	ret
data_pwords:
	call	define_data
	lods	byte [esi]
	cmp	al,'('
	je	get_pword
	cmp	al,'?'
	jne	invalid_argument
	mov	eax,edi
	and	dword [edi],0
	scas	dword [edi]
	and	word [edi],0
	scas	word [edi]
	jmp	undefined_data
      get_pword:
	push	esi
	call	get_pword_value
	pop	ebx
	cmp	byte [esi],':'
	je	complex_pword
	call	mark_relocation
	stos	dword [edi]
	mov	ax,dx
	stos	word [edi]
	ret
      complex_pword:
	mov	esi,ebx
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_word_value
	push	eax
	inc	esi
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_operand
	mov	al,[value_type]
	push	eax
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	call	mark_relocation
	stos	dword [edi]
	pop	eax
	mov	[value_type],al
	pop	eax
	call	mark_relocation
	stos	word [edi]
	ret
data_qwords:
	call	define_data
	lods	byte [esi]
	cmp	al,'('
	je	get_qword
	cmp	al,'?'
	jne	invalid_argument
	mov	eax,edi
	and	dword [edi],0
	scas	dword [edi]
	and	dword [edi],0
	scas	dword [edi]
	jmp	undefined_data
      get_qword:
	call	get_qword_value
	call	mark_relocation
	stos	dword [edi]
	mov	eax,edx
	stos	dword [edi]
	ret
data_twords:
	call	define_data
	lods	byte [esi]
	cmp	al,'('
	je	get_tword
	cmp	al,'?'
	jne	invalid_argument
	mov	eax,edi
	and	dword [edi],0
	scas	dword [edi]
	and	dword [edi],0
	scas	dword [edi]
	and	word [edi],0
	scas	word [edi]
	jmp	undefined_data
      get_tword:
	cmp	byte [esi],'.'
	jne	complex_tword
	inc	esi
	cmp	word [esi+8],8000h
	je	fp_zero_tword
	mov	eax,[esi]
	stos	dword [edi]
	mov	eax,[esi+4]
	stos	dword [edi]
	mov	ax,[esi+8]
	add	ax,3FFFh
	jo	value_out_of_range
	cmp	ax,7FFFh
	jge	value_out_of_range
	cmp	ax,0
	jg	tword_exp_ok
	mov	cx,ax
	neg	cx
	inc	cx
	cmp	cx,64
	jae	value_out_of_range
	cmp	cx,32
	ja	large_shift
	mov	eax,[esi]
	mov	edx,[esi+4]
	mov	ebx,edx
	shr	edx,cl
	shrd	eax,ebx,cl
	jmp	tword_mantissa_shift_done
      large_shift:
	sub	cx,32
	xor	edx,edx
	mov	eax,[esi+4]
	shr	eax,cl
      tword_mantissa_shift_done:
	jnc	store_shifted_mantissa
	add	eax,1
	adc	edx,0
      store_shifted_mantissa:
	mov	[edi-8],eax
	mov	[edi-4],edx
	xor	ax,ax
	test	edx,1 shl 31
	jz	tword_exp_ok
	inc	ax
      tword_exp_ok:
	mov	bl,[esi+11]
	shl	bx,15
	or	ax,bx
	stos	word [edi]
	add	esi,13
	ret
      fp_zero_tword:
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	mov	al,[esi+11]
	shl	ax,15
	stos	word [edi]
	add	esi,13
	ret
      complex_tword:
	call	get_word_value
	push	eax
	cmp	byte [esi],':'
	jne	invalid_operand
	inc	esi
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_operand
	mov	al,[value_type]
	push	eax
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_qword_value
	call	mark_relocation
	stos	dword [edi]
	mov	eax,edx
	stos	dword [edi]
	pop	eax
	mov	[value_type],al
	pop	eax
	call	mark_relocation
	stos	word [edi]
	ret
data_file:
	lods	word [esi]
	cmp	ax,'('
	jne	invalid_argument
	add	esi,4
	call	open_binary_file
	mov	eax,[esi-4]
	lea	esi,[esi+eax+1]
	mov	al,2
	xor	edx,edx
	call	lseek
	push	eax
	xor	edx,edx
	cmp	byte [esi],':'
	jne	position_ok
	inc	esi
	cmp	byte [esi],'('
	jne	invalid_argument
	inc	esi
	cmp	byte [esi],'.'
	je	invalid_value
	push	ebx
	call	get_count_value
	pop	ebx
	mov	edx,eax
	sub	[esp],edx
	jc	value_out_of_range
      position_ok:
	cmp	byte [esi],','
	jne	size_ok
	inc	esi
	cmp	byte [esi],'('
	jne	invalid_argument
	inc	esi
	cmp	byte [esi],'.'
	je	invalid_value
	push	ebx edx
	call	get_count_value
	pop	edx ebx
	cmp	eax,[esp]
	ja	value_out_of_range
	mov	[esp],eax
      size_ok:
	xor	al,al
	call	lseek
	pop	ecx
	mov	edx,edi
	add	edi,ecx
	jc	out_of_memory
	cmp	edi,[tagged_blocks]
	ja	out_of_memory
	call	read
	jc	error_reading_file
	call	close
	lods	byte [esi]
	cmp	al,','
	je	data_file
	dec	esi
	jmp	instruction_assembled
      open_binary_file:
	push	esi
	push	edi
	mov	eax,[current_line]
      find_current_source_path: 
	mov	esi,[eax] 
	test	byte [eax+7],80h 
	jz	get_current_path 
	mov	eax,[eax+8]
	jmp	find_current_source_path
      get_current_path:
	lodsb
	stosb
	or	al,al
	jnz	get_current_path
      cut_current_path:
	cmp	edi,[esp]
	je	current_path_ok
	cmp	byte [edi-1],'\'
	je	current_path_ok
	cmp	byte [edi-1],'/'
	je	current_path_ok
	dec	edi
	jmp	cut_current_path
      current_path_ok:
	mov	esi,[esp+4]
	call	expand_path
	pop	edx
	mov	esi,edx
	call	open
	jnc	file_opened
	mov	edx,[include_paths]
      search_in_include_paths:
	push	edx esi
	mov	edi,esi
	mov	esi,[esp+4]
	call	get_include_directory
	mov	[esp+4],esi
	mov	esi,[esp+8]
	call	expand_path
	pop	edx
	mov	esi,edx
	call	open
	pop	edx
	jnc	file_opened
	cmp	byte [edx],0
	jne	search_in_include_paths
	mov	edi,esi
	mov	esi,[esp]
	push	edi
	call	expand_path
	pop	edx
	mov	esi,edx
	call	open
	jc	file_not_found
      file_opened:
	mov	edi,esi
	pop	esi
	ret
reserve_bytes:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	ecx,eax
	mov	edx,ecx
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[tagged_blocks]
	ja	out_of_memory
	push	edi
	cmp	[next_pass_needed],0
	je	zero_bytes
	add	edi,ecx
	jmp	reserved_data
      zero_bytes:
	xor	eax,eax
	shr	ecx,1
	jnc	bytes_stosb_ok
	stos	byte [edi]
      bytes_stosb_ok:
	shr	ecx,1
	jnc	bytes_stosw_ok
	stos	word [edi]
      bytes_stosw_ok:
	rep	stos dword [edi]
      reserved_data:
	pop	eax
	call	undefined_data
	jmp	instruction_assembled
reserve_words:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[tagged_blocks]
	ja	out_of_memory
	push	edi
	cmp	[next_pass_needed],0
	je	zero_words
	lea	edi,[edi+ecx*2]
	jmp	reserved_data
      zero_words:
	xor	eax,eax
	shr	ecx,1
	jnc	words_stosw_ok
	stos	word [edi]
      words_stosw_ok:
	rep	stos dword [edi]
	jmp	reserved_data
reserve_dwords:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[tagged_blocks]
	ja	out_of_memory
	push	edi
	cmp	[next_pass_needed],0
	je	zero_dwords
	lea	edi,[edi+ecx*4]
	jmp	reserved_data
      zero_dwords:
	xor	eax,eax
	rep	stos dword [edi]
	jmp	reserved_data
reserve_pwords:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	ecx,eax
	shl	ecx,1
	jc	out_of_memory
	add	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[tagged_blocks]
	ja	out_of_memory
	push	edi
	cmp	[next_pass_needed],0
	je	zero_words
	lea	edi,[edi+ecx*2]
	jmp	reserved_data
reserve_qwords:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	ecx,eax
	shl	ecx,1
	jc	out_of_memory
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[tagged_blocks]
	ja	out_of_memory
	push	edi
	cmp	[next_pass_needed],0
	je	zero_dwords
	lea	edi,[edi+ecx*4]
	jmp	reserved_data
reserve_twords:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	ecx,eax
	shl	ecx,2
	jc	out_of_memory
	add	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[tagged_blocks]
	ja	out_of_memory
	push	edi
	cmp	[next_pass_needed],0
	je	zero_words
	lea	edi,[edi+ecx*2]
	jmp	reserved_data
align_directive:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	edx,eax
	dec	edx
	test	eax,edx
	jnz	invalid_align_value
	or	eax,eax
	jz	invalid_align_value
	cmp	eax,1
	je	instruction_assembled
	mov	ecx,edi
	mov	ebp,[addressing_space]
	sub	ecx,[ds:ebp]
	cmp	dword [ds:ebp+10h],0
	jne	section_not_aligned_enough
	cmp	byte [ds:ebp+9],0
	je	make_alignment
	cmp	[output_format],3
	je	pe_alignment
	mov	ebx,[ds:ebp+14h]
	cmp	byte [ebx],0
	jne	section_not_aligned_enough
	cmp	eax,[ebx+10h]
	jbe	make_alignment
	jmp	section_not_aligned_enough
      pe_alignment:
	cmp	eax,1000h
	ja	section_not_aligned_enough
      make_alignment:
	dec	eax
	and	ecx,eax
	jz	instruction_assembled
	neg	ecx
	add	ecx,eax
	inc	ecx
	mov	edx,ecx
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[tagged_blocks]
	ja	out_of_memory
	push	edi
	cmp	[next_pass_needed],0
	je	nops
	add	edi,ecx
	jmp	reserved_data
      invalid_align_value:
	cmp	[error_line],0
	jne	instruction_assembled
	mov	eax,[current_line]
	mov	[error_line],eax
	mov	[error],invalid_value
	jmp	instruction_assembled
      nops:
	mov	eax,90909090h
	shr	ecx,1
	jnc	nops_stosb_ok
	stos	byte [edi]
      nops_stosb_ok:
	shr	ecx,1
	jnc	nops_stosw_ok
	stos	word [edi]
      nops_stosw_ok:
	rep	stos dword [edi]
	jmp	reserved_data
err_directive:
	mov	al,[esi]
	cmp	al,0Fh
	je	invoked_error
	or	al,al
	jz	invoked_error
	jmp	extra_characters_on_line
assert_directive:
	call	calculate_logical_expression
	or	al,al
	jnz	instruction_assembled
	cmp	[error_line],0
	jne	instruction_assembled
	mov	eax,[current_line]
	mov	[error_line],eax
	mov	[error],assertion_failed
	jmp	instruction_assembled




# Formats

formatter:
	mov	[current_offset],edi
	cmp	[output_file],0
	jne	output_path_ok
	mov	esi,[input_file]
	mov	edi,[free_additional_memory]
      copy_output_path:
	lods	byte [esi]
	cmp	edi,[structures_buffer]
	jae	out_of_memory
	stos	byte [edi]
	or	al,al
	jnz	copy_output_path
	dec	edi
	mov	eax,edi
      find_extension:
	dec	eax
	cmp	eax,[free_additional_memory]
	jb	extension_found
	cmp	byte [eax],'\'
	je	extension_found
	cmp	byte [eax],'/'
	je	extension_found
	cmp	byte [eax],'.'
	jne	find_extension
	mov	edi,eax
      extension_found:
	lea	eax,[edi+9]
	cmp	eax,[structures_buffer]
	jae	out_of_memory
	cmp	[file_extension],0
	jne	extension_specified
	mov	al,[output_format]
	cmp	al,2
	je	exe_extension
	jb	bin_extension
	cmp	al,4
	je	obj_extension
	cmp	al,5
	je	o_extension
	cmp	al,3
	jne	no_extension
	cmp	[subsystem],1
	je	sys_extension
	cmp	[subsystem],10
	jae	efi_extension
	bt	[format_flags],8
	jnc	exe_extension
	mov	eax,'.dll'
	jmp	make_extension
      sys_extension:
	mov	eax,'.sys'
	jmp	make_extension
      efi_extension:
	mov	eax,'.efi'
	jmp	make_extension
      bin_extension:
	mov	eax,'.bin'
	bt	[format_flags],0
	jnc	make_extension
	mov	eax,'.com'
	jmp	make_extension
      obj_extension:
	mov	eax,'.obj'
	jmp	make_extension
      o_extension:
	mov	eax,'.o'
	bt	[format_flags],0
	jnc	make_extension
      no_extension:
	xor	eax,eax
	jmp	make_extension
      exe_extension:
	mov	eax,'.exe'
      make_extension:
	xchg	eax,[edi]
	scas	dword [edi]
	mov	byte [edi],0
	scas	byte [edi]
	mov	esi,edi
	stos	dword [edi]
	sub	edi,9
	xor	eax,eax
	mov	ebx,characters
      adapt_case:
	mov	al,[esi]
	or	al,al
	jz	adapt_next
	xlat	byte [ebx]
	cmp	al,[esi]
	je	adapt_ok
	sub	byte [edi],20h
      adapt_ok:
	inc	esi
      adapt_next:
	inc	edi
	cmp	byte [edi],0
	jne	adapt_case
	jmp	extension_ok
      extension_specified:
	mov	al,'.'
	stos	byte [edi]
	mov	esi,[file_extension]
      copy_extension:
	lods	byte [esi]
	stos	byte [edi]
	test	al,al
	jnz	copy_extension
	dec	edi
      extension_ok:
	mov	esi,edi
	lea	ecx,[esi+1]
	sub	ecx,[free_additional_memory]
	mov	edi,[structures_buffer]
	dec	edi
	std
	rep	movs byte [edi],[esi]
	cld
	inc	edi
	mov	[structures_buffer],edi
	mov	[output_file],edi
      output_path_ok:
	cmp	[symbols_file],0
	je	labels_table_ok
	mov	ecx,[memory_end]
	sub	ecx,[labels_list]
	mov	edi,[tagged_blocks]
	sub	edi,8
	mov	[edi],ecx
	or	dword [edi+4],-1
	sub	edi,ecx
	cmp	edi,[current_offset]
	jbe	out_of_memory
	mov	[tagged_blocks],edi
	mov	esi,[memory_end]
      copy_labels:
	sub	esi,32
	cmp	esi,[labels_list]
	jb	labels_table_ok
	mov	ecx,32 shr 2
	rep	movs dword [edi],[esi]
	sub	esi,32
	jmp	copy_labels
      labels_table_ok:
	mov	edi,[current_offset]
	cmp	[output_format],4
	je	coff_formatter
	cmp	[output_format],5
	jne	common_formatter
	bt	[format_flags],0
	jnc	elf_formatter
      common_formatter:
	mov	eax,edi
	sub	eax,[code_start]
	mov	[real_code_size],eax
	cmp	edi,[undefined_data_end]
	jne	calculate_code_size
	mov	edi,[undefined_data_start]
      calculate_code_size:
	mov	[current_offset],edi
	sub	edi,[code_start]
	mov	[code_size],edi
	and	[written_size],0
	mov	edx,[output_file]
	call	create
	jc	write_failed
	cmp	[output_format],3
	jne	stub_written
	mov	edx,[code_start]
	mov	ecx,[stub_size]
	sub	edx,ecx
	add	[written_size],ecx
	call	write
      stub_written:
	cmp	[output_format],2
	jne	write_output
	call	write_mz_header
      write_output:
	call	write_code
      output_written:
	call	close
	cmp	[symbols_file],0
	jne	dump_symbols
	ret
      write_code:
	mov	eax,[written_size]
	mov	[headers_size],eax
	mov	edx,[code_start]
	mov	ecx,[code_size]
	add	[written_size],ecx
	lea	eax,[edx+ecx]
	call	write
	jc	write_failed
	ret
format_directive:
	cmp	edi,[code_start]
	jne	unexpected_instruction
	mov	ebp,[addressing_space]
	test	byte [ds:ebp+0Ah],1
	jnz	unexpected_instruction
	cmp	[output_format],0
	jne	unexpected_instruction
	lods	byte [esi]
	cmp	al,1Ch
	je	format_prefix
	cmp	al,18h
	jne	invalid_argument
	lods	byte [esi]
      select_format:
	mov	dl,al
	shr	al,4
	mov	[output_format],al
	and	edx,0Fh
	or	[format_flags],edx
	cmp	al,2
	je	format_mz
	cmp	al,3
	je	format_pe
	cmp	al,4
	je	format_coff
	cmp	al,5
	je	format_elf
      format_defined:
	cmp	byte [esi],86h
	jne	instruction_assembled
	cmp	word [esi+1],'('
	jne	invalid_argument
	mov	eax,[esi+3]
	add	esi,3+4
	mov	[file_extension],esi
	lea	esi,[esi+eax+1]
	jmp	instruction_assembled
      format_prefix:
	lods	byte [esi]
	mov	ah,al
	lods	byte [esi]
	cmp	al,18h
	jne	invalid_argument
	lods	byte [esi]
	mov	edx,eax
	shr	dl,4
	shr	dh,4
	cmp	dl,dh
	jne	invalid_argument
	or	al,ah
	jmp	select_format
entry_directive:
	bts	[format_flags],10h
	jc	setting_already_specified
	mov	al,[output_format]
	cmp	al,2
	je	mz_entry
	cmp	al,3
	je	pe_entry
	cmp	al,5
	jne	illegal_instruction
	bt	[format_flags],0
	jc	elf_entry
	jmp	illegal_instruction
stack_directive:
	bts	[format_flags],11h
	jc	setting_already_specified
	mov	al,[output_format]
	cmp	al,2
	je	mz_stack
	cmp	al,3
	je	pe_stack
	jmp	illegal_instruction
heap_directive:
	bts	[format_flags],12h
	jc	setting_already_specified
	mov	al,[output_format]
	cmp	al,2
	je	mz_heap
	cmp	al,3
	je	pe_heap
	jmp	illegal_instruction
segment_directive:
	mov	al,[output_format]
	cmp	al,2
	je	mz_segment
	cmp	al,5
	je	elf_segment
	jmp	illegal_instruction
section_directive:
	mov	al,[output_format]
	cmp	al,3
	je	pe_section
	cmp	al,4
	je	coff_section
	cmp	al,5
	je	elf_section
	jmp	illegal_instruction
public_directive:
	mov	al,[output_format]
	cmp	al,4
	je	public_allowed
	cmp	al,5
	jne	illegal_instruction
	bt	[format_flags],0
	jc	illegal_instruction
      public_allowed:
	mov	[base_code],0C0h
	lods	byte [esi]
	cmp	al,2
	je	public_label
	cmp	al,1Dh
	jne	invalid_argument
	lods	byte [esi]
	and	al,7
	add	[base_code],al
	lods	byte [esi]
	cmp	al,2
	jne	invalid_argument
      public_label:
	lods	dword [esi]
	cmp	eax,0Fh
	jb	invalid_use_of_symbol
	je	reserved_word_used_as_symbol
	inc	esi
	mov	dx,[current_pass]
	mov	[eax+18],dx
	or	byte [eax+8],8
	cmp	[symbols_file],0
	je	public_reference_ok
	cmp	[next_pass_needed],0
	jne	public_reference_ok
	mov	ebx,eax
	call	store_label_reference
	mov	eax,ebx
      public_reference_ok:
	mov	ebx,[free_additional_memory]
	lea	edx,[ebx+10h]
	cmp	edx,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],edx
	mov	[ebx+8],eax
	mov	eax,[current_line]
	mov	[ebx+0Ch],eax
	lods	byte [esi]
	cmp	al,86h
	jne	invalid_argument
	lods	word [esi]
	cmp	ax,'('
	jne	invalid_argument
	mov	[ebx+4],esi
	lods	dword [esi]
	lea	esi,[esi+eax+1]
	mov	al,[base_code]
	mov	[ebx],al
	jmp	instruction_assembled
extrn_directive:
	mov	al,[output_format]
	cmp	al,4
	je	extrn_allowed
	cmp	al,5
	jne	illegal_instruction
	bt	[format_flags],0
	jc	illegal_instruction
      extrn_allowed:
	lods	word [esi]
	cmp	ax,'('
	jne	invalid_argument
	mov	ebx,esi
	lods	dword [esi]
	lea	esi,[esi+eax+1]
	mov	edx,[free_additional_memory]
	lea	eax,[edx+0Ch]
	cmp	eax,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],eax
	mov	byte [edx],80h
	mov	[edx+4],ebx
	lods	byte [esi]
	cmp	al,86h
	jne	invalid_argument
	lods	byte [esi]
	cmp	al,2
	jne	invalid_argument
	lods	dword [esi]
	cmp	eax,0Fh
	jb	invalid_use_of_symbol
	je	reserved_word_used_as_symbol
	inc	esi
	mov	ebx,eax
	xor	ah,ah
	lods	byte [esi]
	cmp	al,':'
	je	get_extrn_size
	dec	esi
	cmp	al,11h
	jne	extrn_size_ok
      get_extrn_size:
	lods	word [esi]
	cmp	al,11h
	jne	invalid_argument
      extrn_size_ok:
	mov	[address_symbol],edx
	mov	[label_size],ah
	movzx	ecx,ah
	mov	[edx+8],ecx
	xor	eax,eax
	xor	edx,edx
	xor	ebp,ebp
	mov	[address_sign],0
	mov	ch,2
	test	[format_flags],8
	jz	make_free_label
	mov	ch,4
	jmp	make_free_label
mark_relocation:
	cmp	[value_type],0
	je	relocation_ok
	mov	ebp,[addressing_space]
	test	byte [ds:ebp+0Ah],1
	jnz	relocation_ok
	cmp	[output_format],2
	je	mark_mz_relocation
	cmp	[output_format],3
	je	mark_pe_relocation
	cmp	[output_format],4
	je	mark_coff_relocation
	cmp	[output_format],5
	je	mark_elf_relocation
      relocation_ok:
	ret
close_pass:
	mov	al,[output_format]
	cmp	al,3
	je	close_pe
	cmp	al,4
	je	close_coff
	cmp	al,5
	je	close_elf
	ret

format_mz:
	mov	edx,[additional_memory]
	push	edi
	mov	edi,edx
	mov	ecx,1Ch shr 2
	xor	eax,eax
	rep	stos dword [edi]
	mov	[free_additional_memory],edi
	pop	edi
	mov	word [edx+0Ch],0FFFFh
	mov	word [edx+10h],1000h
	mov	[code_type],16
	jmp	format_defined
mark_mz_relocation:
	push	eax ebx
	inc	word [number_of_relocations]
	jz	format_limitations_exceeded
	mov	ebx,[free_additional_memory]
	mov	eax,edi
	sub	eax,[code_start]
	mov	[ebx],ax
	shr	eax,16
	shl	ax,12
	mov	[ebx+2],ax
	cmp	word [ebx],0FFFFh
	jne	mz_relocation_ok
	inc	word [ebx+2]
	sub	word [ebx],10h
      mz_relocation_ok:
	add	ebx,4
	cmp	ebx,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],ebx
	pop	ebx eax
	ret
mz_segment:
	lods	byte [esi]
	cmp	al,2
	jne	invalid_argument
	lods	dword [esi]
	cmp	eax,0Fh
	jb	invalid_use_of_symbol
	je	reserved_word_used_as_symbol
	inc	esi
	mov	ebx,eax
	mov	eax,edi
	sub	eax,[code_start]
	mov	ecx,0Fh
	add	eax,0Fh
	and	eax,1111b
	sub	ecx,eax
	mov	edx,edi
	xor	eax,eax
	rep	stos byte [edi]
	mov	eax,edx
	call	undefined_data
	push	ebx
	call	create_addressing_space
	pop	ebx
	mov	eax,edi
	sub	eax,[code_start]
	shr	eax,4
	cmp	eax,10000h
	jae	value_out_of_range
	mov	edx,eax
	mov	al,16
	cmp	byte [esi],13h
	jne	segment_type_ok
	inc	esi
	lods	byte [esi]
      segment_type_ok:
	mov	[code_type],al
	mov	eax,edx
	mov	ch,1
	mov	[address_sign],0
	xor	edx,edx
	xor	ebp,ebp
	mov	[label_size],0
	mov	[address_symbol],edx
	jmp	make_free_label
mz_entry:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	call	get_word_value
	cmp	[value_type],1
	je	initial_cs_ok
	call	recoverable_invalid_address
      initial_cs_ok:
	mov	edx,[additional_memory]
	mov	[edx+16h],ax
	lods	byte [esi]
	cmp	al,':'
	jne	invalid_argument
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	ja	invalid_address
	call	get_word_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[additional_memory]
	mov	[edx+14h],ax
	jmp	instruction_assembled
      recoverable_invalid_address:
	cmp	[error_line],0
	jne	ignore_invalid_address
	push	[current_line]
	pop	[error_line]
	mov	[error],invalid_address
      ignore_invalid_address:
	ret
mz_stack:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	call	get_word_value
	cmp	byte [esi],':'
	je	stack_pointer
	cmp	ax,10h
	jb	invalid_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[additional_memory]
	mov	[edx+10h],ax
	jmp	instruction_assembled
      stack_pointer:
	cmp	[value_type],1
	je	initial_ss_ok
	call	recoverable_invalid_address
      initial_ss_ok:
	mov	edx,[additional_memory]
	mov	[edx+0Eh],ax
	lods	byte [esi]
	cmp	al,':'
	jne	invalid_argument
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	call	get_word_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[additional_memory]
	mov	[edx+10h],ax
	bts	[format_flags],4
	jmp	instruction_assembled
mz_heap:
	cmp	[output_format],2
	jne	illegal_instruction
	lods	byte [esi]
	call	get_size_operator
	cmp	ah,1
	je	invalid_value
	cmp	ah,2
	ja	invalid_value
	cmp	al,'('
	jne	invalid_argument
	call	get_word_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[additional_memory]
	mov	[edx+0Ch],ax
	jmp	instruction_assembled
write_mz_header:
	mov	edx,[additional_memory]
	bt	[format_flags],4
	jc	mz_stack_ok
	mov	eax,[real_code_size]
	dec	eax
	shr	eax,4
	inc	eax
	mov	[edx+0Eh],ax
	shl	eax,4
	movzx	ecx,word [edx+10h]
	add	eax,ecx
	mov	[real_code_size],eax
      mz_stack_ok:
	mov	edi,[free_additional_memory]
	mov	eax,[number_of_relocations]
	shl	eax,2
	add	eax,1Ch
	sub	edi,eax
	xchg	edi,[free_additional_memory]
	mov	ecx,0Fh
	add	eax,0Fh
	and	eax,1111b
	sub	ecx,eax
	xor	al,al
	rep	stos byte [edi]
	sub	edi,[free_additional_memory]
	mov	ecx,edi
	shr	edi,4
	mov	word [edx],'MZ' 	# signature
	mov	[edx+8],di		# header size in paragraphs
	mov	eax,[number_of_relocations]
	mov	[edx+6],ax		# number of relocation entries
	mov	eax,[code_size]
	add	eax,ecx
	mov	esi,eax
	shr	esi,9
	and	eax,1FFh
	inc	si
	or	ax,ax
	jnz	mz_size_ok
	dec	si
      mz_size_ok:
	mov	[edx+2],ax		# number of bytes in last page
	mov	[edx+4],si		# number of pages
	mov	eax,[real_code_size]
	dec	eax
	shr	eax,4
	inc	eax
	mov	esi,[code_size]
	dec	esi
	shr	esi,4
	inc	esi
	sub	eax,esi
	mov	[edx+0Ah],ax		# minimum memory in addition to code
	add	[edx+0Ch],ax		# maximum memory in addition to code
	salc
	mov	ah,al
	or	[edx+0Ch],ax
	mov	word [edx+18h],1Ch	# offset of relocation table
	add	[written_size],ecx
	call	write
	jc	write_failed
	ret

make_stub:
	mov	[stub_file],edx
	or	edx,edx
	jnz	stub_from_file
	push	esi
	mov	edx,edi
	xor	eax,eax
	mov	ecx,20h
	rep	stos dword [edi]
	mov	eax,40h+default_stub_end-default_stub
	mov	cx,100h+default_stub_end-default_stub
	mov	word [edx],'MZ'
	mov	byte [edx+4],1
	mov	word [edx+2],ax
	mov	byte [edx+8],4
	mov	byte [edx+0Ah],10h
	mov	word [edx+0Ch],0FFFFh
	mov	word [edx+10h],cx
	mov	word [edx+3Ch],ax
	mov	byte [edx+18h],40h
	lea	edi,[edx+40h]
	mov	esi,default_stub
	mov	ecx,default_stub_end-default_stub
	rep	movs byte [edi],[esi]
	pop	esi
	jmp	stub_ok
      default_stub:
	use16
	push	cs
	pop	ds
	mov	dx,stub_message-default_stub
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h
      stub_message db 'This program cannot be run in DOS mode.',0Dh,0Ah,24h
	rq	1
      default_stub_end:
	use32
      stub_from_file:
	push	esi
	mov	esi,edx
	call	open_binary_file
	mov	edx,edi
	mov	ecx,1Ch
	mov	esi,edx
	call	read
	jc	binary_stub
	cmp	word [esi],'MZ'
	jne	binary_stub
	add	edi,1Ch
	movzx	ecx,word [esi+6]
	add	ecx,11b
	and	ecx,not 11b
	add	ecx,(40h-1Ch) shr 2
	lea	eax,[edi+ecx*4]
	cmp	edi,[tagged_blocks]
	jae	out_of_memory
	xor	eax,eax
	rep	stos dword [edi]
	mov	edx,40h
	xchg	dx,[esi+18h]
	xor	al,al
	call	lseek
	movzx	ecx,word [esi+6]
	shl	ecx,2
	lea	edx,[esi+40h]
	call	read
	mov	edx,edi
	sub	edx,esi
	shr	edx,4
	xchg	dx,[esi+8]
	shl	edx,4
	xor	al,al
	call	lseek
	movzx	ecx,word [esi+4]
	dec	ecx
	shl	ecx,9
	movzx	edx,word [esi+2]
	test	edx,edx
	jnz	stub_header_size_ok
	mov	dx,200h
     stub_header_size_ok:
	add	ecx,edx
	mov	edx,edi
	sub	ecx,eax
	je	read_stub_code
	jb	stub_code_ok
	push	ecx
	dec	ecx
	shr	ecx,3
	inc	ecx
	shl	ecx,1
	lea	eax,[edi+ecx*4]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	xor	eax,eax
	rep	stos dword [edi]
	pop	ecx
     read_stub_code:
	call	read
     stub_code_ok:
	call	close
	mov	edx,edi
	sub	edx,esi
	mov	ax,dx
	and	ax,1FFh
	mov	[esi+2],ax
	dec	edx
	shr	edx,9
	inc	edx
	mov	[esi+4],dx
	mov	eax,edi
	sub	eax,esi
	mov	[esi+3Ch],eax
	pop	esi
      stub_ok:
	ret
      binary_stub:
	mov	esi,edi
	mov	ecx,40h shr 2
	xor	eax,eax
	rep	stos dword [edi]
	mov	al,2
	xor	edx,edx
	call	lseek
	push	eax
	xor	al,al
	xor	edx,edx
	call	lseek
	mov	ecx,[esp]
	add	ecx,40h+111b
	and	ecx,not 111b
	mov	ax,cx
	and	ax,1FFh
	mov	[esi+2],ax
	lea	eax,[ecx+1FFh]
	shr	eax,9
	mov	[esi+4],ax
	mov	[esi+3Ch],ecx
	sub	ecx,40h
	mov	eax,10000h
	sub	eax,ecx
	jbe	binary_heap_ok
	shr	eax,4
	mov	[esi+0Ah],ax
      binary_heap_ok:
	mov	word [esi],'MZ'
	mov	byte [esi+8],4
	mov	ax,0FFFFh
	mov	[esi+0Ch],ax
	dec	ax
	mov	[esi+10h],ax
	sub	ax,0Eh
	mov	[esi+0Eh],ax
	mov	[esi+16h],ax
	mov	word [esi+14h],100h
	mov	byte [esi+18h],40h
	mov	eax,[tagged_blocks]
	sub	eax,ecx
	cmp	edi,eax
	jae	out_of_memory
	mov	edx,edi
	shr	ecx,2
	xor	eax,eax
	rep	stos dword [edi]
	pop	ecx
	call	read
	call	close
	pop	esi
	ret

format_pe:
	xor	edx,edx
	mov	[machine],14Ch
	mov	[subsystem],3
	mov	[subsystem_version],3 + 10 shl 16
	mov	[image_base],400000h
	and	[image_base_high],0
	test	[format_flags],8
	jz	pe_settings
	mov	[machine],8664h
	mov	[subsystem_version],5 + 0 shl 16
      pe_settings:
	cmp	byte [esi],84h
	je	get_stub_name
	cmp	byte [esi],80h
	je	get_pe_base
	cmp	byte [esi],1Bh
	jne	pe_settings_ok
	lods	byte [esi]
	lods	byte [esi]
	test	al,80h+40h
	jz	subsystem_setting
	cmp	al,80h
	je	dll_flag
	cmp	al,81h
	je	wdm_flag
	cmp	al,82h
	je	large_flag
	cmp	al,83h
	je	nx_flag
	jmp	pe_settings
      dll_flag:
	bts	[format_flags],8
	jc	setting_already_specified
	jmp	pe_settings
      wdm_flag:
	bts	[format_flags],9
	jc	setting_already_specified
	jmp	pe_settings
      large_flag:
	bts	[format_flags],11
	jc	setting_already_specified
	test	[format_flags],8
	jnz	invalid_argument
	jmp	pe_settings
      nx_flag:
	bts	[format_flags],12
	jc	setting_already_specified
	jmp	pe_settings
      subsystem_setting:
	bts	[format_flags],7
	jc	setting_already_specified
	and	ax,3Fh
	mov	[subsystem],ax
	cmp	ax,10
	jb	subsystem_type_ok
	or	[format_flags],4
      subsystem_type_ok:
	cmp	byte [esi],'('
	jne	pe_settings
	inc	esi
	cmp	byte [esi],'.'
	jne	invalid_value
	inc	esi
	push	edx
	cmp	byte [esi+11],0
	jne	invalid_value
	cmp	byte [esi+10],2
	ja	invalid_value
	mov	dx,[esi+8]
	cmp	dx,8000h
	je	zero_version
	mov	eax,[esi+4]
	cmp	dx,7
	jg	invalid_value
	mov	cx,7
	sub	cx,dx
	mov	eax,[esi+4]
	shr	eax,cl
	mov	ebx,eax
	shr	ebx,24
	cmp	bl,100
	jae	invalid_value
	and	eax,0FFFFFFh
	mov	ecx,100
	mul	ecx
	shrd	eax,edx,24
	jnc	version_value_ok
	inc	eax
      version_value_ok:
	shl	eax,16
	mov	ax,bx
	jmp	subsystem_version_ok
      zero_version:
	xor	eax,eax
      subsystem_version_ok:
	pop	edx
	add	esi,13
	mov	[subsystem_version],eax
	jmp	pe_settings
      get_pe_base:
	bts	[format_flags],10
	jc	setting_already_specified
	lods	word [esi]
	cmp	ah,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	push	edx edi
	add	edi,[stub_size]
	test	[format_flags],4
	jnz	get_peplus_base
	call	get_dword_value
	mov	[image_base],eax
	jmp	pe_base_ok
      get_peplus_base:
	call	get_qword_value
	mov	[image_base],eax
	mov	[image_base_high],edx
      pe_base_ok:
	pop	edi edx
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	cmp	byte [esi],84h
	jne	pe_settings_ok
      get_stub_name:
	lods	byte [esi]
	lods	word [esi]
	cmp	ax,'('
	jne	invalid_argument
	lods	dword [esi]
	mov	edx,esi
	add	esi,eax
	inc	esi
      pe_settings_ok:
	mov	ebp,[stub_size]
	or	ebp,ebp
	jz	make_pe_stub
	cmp	edx,[stub_file]
	je	pe_stub_ok
	sub	edi,[stub_size]
	mov	[code_start],edi
      make_pe_stub:
	call	make_stub
	mov	eax,edi
	sub	eax,[code_start]
	mov	[stub_size],eax
	mov	[code_start],edi
	mov	ebp,eax
      pe_stub_ok:
	mov	edx,edi
	mov	ecx,18h+0E0h
	test	[format_flags],4
	jz	zero_pe_header
	add	ecx,10h
      zero_pe_header:
	add	ebp,ecx
	shr	ecx,2
	xor	eax,eax
	rep	stos dword [edi]
	mov	word [edx],'PE' 	# signature
	mov	ax,[machine]
	mov	word [edx+4],ax
	mov	byte [edx+38h+1],10h	# section alignment
	mov	byte [edx+3Ch+1],2	# file alignment
	mov	byte [edx+40h],1	# OS version
	mov	eax,[subsystem_version]
	mov	[edx+48h],eax
	mov	ax,[subsystem]
	mov	[edx+5Ch],ax
	cmp	ax,1
	jne	pe_alignment_ok
	mov	eax,20h
	mov	dword [edx+38h],eax
	mov	dword [edx+3Ch],eax
      pe_alignment_ok:
	mov	word [edx+1Ah],VERSION_MAJOR + VERSION_MINOR shl 8
	test	[format_flags],4
	jnz	init_peplus_specific
	mov	byte [edx+14h],0E0h	# size of optional header
	mov	dword [edx+16h],10B010Fh# flags and magic value
	mov	eax,[image_base]
	mov	[edx+34h],eax
	mov	byte [edx+60h+1],10h	# stack reserve
	mov	byte [edx+64h+1],10h	# stack commit
	mov	byte [edx+68h+2],1	# heap reserve
	mov	byte [edx+74h],16	# number of directories
	jmp	pe_header_ok
      init_peplus_specific:
	mov	byte [edx+14h],0F0h	# size of optional header
	mov	dword [edx+16h],20B002Fh # flags and magic value
	mov	eax,[image_base]
	mov	[edx+30h],eax
	mov	eax,[image_base_high]
	mov	[edx+34h],eax
	mov	byte [edx+60h+1],10h	# stack reserve
	mov	byte [edx+68h+1],10h	# stack commit
	mov	byte [edx+70h+2],1	# heap reserve
	mov	byte [edx+84h],16	# number of directories
      pe_header_ok:
	bsf	ecx,[edx+3Ch]
	imul	ebx,[number_of_sections],28h
	or	ebx,ebx
	jnz	reserve_space_for_section_headers
	mov	ebx,28h
      reserve_space_for_section_headers:
	add	ebx,ebp
	dec	ebx
	shr	ebx,cl
	inc	ebx
	shl	ebx,cl
	sub	ebx,ebp
	mov	ecx,ebx
	mov	eax,[tagged_blocks]
	sub	eax,ecx
	cmp	edi,eax
	jae	out_of_memory
	shr	ecx,2
	xor	eax,eax
	rep	stos dword [edi]
	mov	eax,edi
	sub	eax,[code_start]
	add	eax,[stub_size]
	mov	[edx+54h],eax		# size of headers
	mov	ecx,[edx+38h]
	dec	ecx
	add	eax,ecx
	not	ecx
	and	eax,ecx
	bt	[format_flags],8
	jc	pe_entry_init_ok
	mov	[edx+28h],eax		# entry point rva
      pe_entry_init_ok:
	and	[number_of_sections],0
	movzx	ebx,word [edx+14h]
	lea	ebx,[edx+18h+ebx]
	mov	[current_section],ebx
	mov	dword [ebx],'.fla'
	mov	dword [ebx+4],'t'
	mov	[ebx+14h],edi
	mov	[ebx+0Ch],eax
	mov	dword [ebx+24h],0E0000060h
	xor	ecx,ecx
	xor	bl,bl
	not	eax
	not	ecx
	not	bl
	add	eax,1
	adc	ecx,0
	adc	bl,0
	add	eax,edi
	adc	ecx,0
	adc	bl,0
	test	[format_flags],4
	jnz	peplus_org
	sub	eax,[edx+34h]
	sbb	ecx,0
	sbb	bl,0
	jmp	pe_org_ok
      peplus_org:
	sub	eax,[edx+30h]
	sbb	ecx,[edx+34h]
	sbb	bl,0
      pe_org_ok:
	test	[format_flags],8
	jnz	pe64_code
	mov	bh,2
	mov	[code_type],32
	jmp	pe_code_type_ok
      pe64_code:
	mov	bh,4
	mov	[code_type],64
      pe_code_type_ok:
	bt	[resolver_flags],0
	jc	pe_labels_type_ok
	xor	bh,bh
      pe_labels_type_ok:
	push	eax ebx
	call	init_addressing_space
	mov	ebp,ebx
	pop	ebx eax
	mov	[ds:ebp],eax
	mov	[ds:ebp+4],ecx
	mov	[ds:ebp+8],bx
	mov	[ds:ebp+18h],edi
	bt	[format_flags],8
	jnc	dll_flag_ok
	or	byte [edx+16h+1],20h
      dll_flag_ok:
	bt	[format_flags],9
	jnc	wdm_flag_ok
	or	byte [edx+5Eh+1],20h
      wdm_flag_ok:
	bt	[format_flags],11
	jnc	large_flag_ok
	or	byte [edx+16h],20h
      large_flag_ok:
	bt	[format_flags],12
	jnc	nx_ok
	or	byte [edx+5Eh+1],1
      nx_ok:
	jmp	format_defined
pe_section:
	call	close_pe_section
	push	eax ebx
	call	create_addressing_space
	mov	ebp,ebx
	pop	ebx eax
	bts	[format_flags],5
	lea	ecx,[ebx+28h]
	add	edx,[edx+54h]
	sub	edx,[stub_size]
	cmp	ecx,edx
	jbe	new_section
	lea	ebx,[edx-28h]
	or	[next_pass_needed],-1
	push	edi
	mov	edi,ebx
	mov	ecx,28h shr 4
	xor	eax,eax
	rep	stos dword [edi]
	pop	edi
      new_section:
	mov	[ebx+0Ch],eax
	lods	word [esi]
	cmp	ax,'('
	jne	invalid_argument
	lea	edx,[esi+4]
	mov	ecx,[esi]
	lea	esi,[esi+4+ecx+1]
	cmp	ecx,8
	ja	name_too_long
	xor	eax,eax
	mov	[ebx],eax
	mov	[ebx+4],eax
	push	esi edi
	mov	edi,ebx
	mov	esi,edx
	rep	movs byte [edi],[esi]
	pop	edi esi
	and	dword [ebx+24h],0
	mov	[ebx+14h],edi
	mov	edx,[code_start]
	mov	eax,edi
	xor	ecx,ecx
	sub	eax,[ebx+0Ch]
	sbb	ecx,0
	sbb	byte [ds:ebp+8],0
	mov	byte [ds:ebp+9],2
	mov	[code_type],32
	test	[format_flags],8
	jz	pe_section_code_type_ok
	mov	byte [ds:ebp+9],4
	mov	[code_type],64
      pe_section_code_type_ok:
	test	[format_flags],4
	jnz	peplus_section_org
	sub	eax,[edx+34h]
	sbb	ecx,0
	sbb	byte [ds:ebp+8],0
	bt	[resolver_flags],0
	jc	pe_section_org_ok
	mov	byte [ds:ebp+9],0
	jmp	pe_section_org_ok
      peplus_section_org:
	sub	eax,[edx+30h]
	sbb	ecx,[edx+34h]
	sbb	byte [ds:ebp+8],0
	bt	[resolver_flags],0
	jc	pe_section_org_ok
	mov	byte [ds:ebp+9],0
      pe_section_org_ok:
	mov	[ds:ebp],eax
	mov	[ds:ebp+4],ecx
	mov	[ds:ebp+18h],edi
      get_section_flags:
	lods	byte [esi]
	cmp	al,1Ah
	je	set_directory
	cmp	al,19h
	je	section_flag
	dec	esi
	jmp	instruction_assembled
      set_directory:
	movzx	eax,byte [esi]
	inc	esi
	mov	ecx,ebx
	test	[format_flags],4
	jnz	peplus_directory
	xchg	ecx,[edx+78h+eax*8]
	mov	dword [edx+78h+eax*8+4],-1
	jmp	pe_directory_set
      peplus_directory:
	xchg	ecx,[edx+88h+eax*8]
	mov	dword [edx+88h+eax*8+4],-1
      pe_directory_set:
	or	ecx,ecx
	jnz	data_already_defined
	push	ebx edx
	call	generate_pe_data
	pop	edx ebx
	jmp	get_section_flags
      section_flag:
	lods	byte [esi]
	cmp	al,9
	je	invalid_argument
	cmp	al,11
	je	invalid_argument
	mov	cl,al
	mov	eax,1
	shl	eax,cl
	test	dword [ebx+24h],eax
	jnz	setting_already_specified
	or	dword [ebx+24h],eax
	jmp	get_section_flags
      close_pe_section:
	mov	ebx,[current_section]
	mov	edx,[code_start]
	mov	eax,edi
	sub	eax,[ebx+14h]
	jnz	finish_section
	bt	[format_flags],5
	jc	finish_section
	mov	eax,[ebx+0Ch]
	ret
      finish_section:
	mov	[ebx+8],eax
	cmp	edi,[undefined_data_end]
	jne	align_section
	cmp	dword [edx+38h],1000h
	jb	align_section
	mov	edi,[undefined_data_start]
      align_section:
	and	[undefined_data_end],0
	mov	ebp,edi
	sub	ebp,[ebx+14h]
	mov	ecx,[edx+3Ch]
	dec	ecx
	lea	eax,[ebp+ecx]
	not	ecx
	and	eax,ecx
	mov	[ebx+10h],eax
	sub	eax,ebp
	mov	ecx,eax
	xor	al,al
	rep	stos byte [edi]
	mov	eax,[code_start]
	sub	eax,[stub_size]
	sub	[ebx+14h],eax
	mov	ecx,[ebx+10h]
	test	byte [ebx+24h],20h
	jz	pe_code_sum_ok
	add	[edx+1Ch],ecx
	cmp	dword [edx+2Ch],0
	jne	pe_code_sum_ok
	mov	eax,[ebx+0Ch]
	mov	[edx+2Ch],eax
      pe_code_sum_ok:
	test	byte [ebx+24h],40h
	jz	pe_data_sum_ok
	add	[edx+20h],ecx
	test	[format_flags],4
	jnz	pe_data_sum_ok
	cmp	dword [edx+30h],0
	jne	pe_data_sum_ok
	mov	eax,[ebx+0Ch]
	mov	[edx+30h],eax
      pe_data_sum_ok:
	mov	eax,[ebx+8]
	or	eax,eax
	jz	udata_ok
	cmp	dword [ebx+10h],0
	jne	udata_ok
	or	byte [ebx+24h],80h
	add	[edx+24h],ecx
      udata_ok:
	mov	ecx,[edx+38h]
	dec	ecx
	add	eax,ecx
	not	ecx
	and	eax,ecx
	add	eax,[ebx+0Ch]
	add	ebx,28h
	mov	[current_section],ebx
	inc	word [number_of_sections]
	jz	format_limitations_exceeded
	ret
data_directive:
	cmp	[output_format],3
	jne	illegal_instruction
	lods	byte [esi]
	cmp	al,1Ah
	je	predefined_data_type
	cmp	al,'('
	jne	invalid_argument
	call	get_byte_value
	cmp	al,16
	jb	data_type_ok
	jmp	invalid_value
      predefined_data_type:
	movzx	eax,byte [esi]
	inc	esi
      data_type_ok:
	mov	ebx,[current_section]
	mov	ecx,edi
	sub	ecx,[ebx+14h]
	add	ecx,[ebx+0Ch]
	mov	edx,[code_start]
	test	[format_flags],4
	jnz	peplus_data
	xchg	ecx,[edx+78h+eax*8]
	jmp	init_pe_data
      peplus_data:
	xchg	ecx,[edx+88h+eax*8]
      init_pe_data:
	or	ecx,ecx
	jnz	data_already_defined
	call	allocate_structure_data
	mov	word [ebx],data_directive-instruction_handler
	mov	[ebx+2],al
	mov	edx,[current_line]
	mov	[ebx+4],edx
	call	generate_pe_data
	jmp	instruction_assembled
      end_data:
	cmp	[output_format],3
	jne	illegal_instruction
	call	find_structure_data
	jc	unexpected_instruction
	movzx	eax,byte [ebx+2]
	mov	edx,[current_section]
	mov	ecx,edi
	sub	ecx,[edx+14h]
	add	ecx,[edx+0Ch]
	mov	edx,[code_start]
	test	[format_flags],4
	jnz	end_peplus_data
	sub	ecx,[edx+78h+eax*8]
	mov	[edx+78h+eax*8+4],ecx
	jmp	remove_structure_data
      end_peplus_data:
	sub	ecx,[edx+88h+eax*8]
	mov	[edx+88h+eax*8+4],ecx
	jmp	remove_structure_data
pe_entry:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	test	[format_flags],8
	jnz	pe64_entry
	call	get_dword_value
	mov	bl,2
	bt	[resolver_flags],0
	jc	check_pe_entry_label_type
	xor	bl,bl
      check_pe_entry_label_type:
	cmp	[value_type],bl
	je	pe_entry_ok
	call	recoverable_invalid_address
      pe_entry_ok:
      cdq
	test	[format_flags],4
	jnz	pe64_entry_type_ok
	mov	edx,[code_start]
	sub	eax,[edx+34h]
	mov	[edx+28h],eax
	jmp	instruction_assembled
      pe64_entry:
	call	get_qword_value
	mov	bl,4
	bt	[resolver_flags],0
	jc	check_pe64_entry_label_type
	xor	bl,bl
      check_pe64_entry_label_type:
	cmp	[value_type],bl
	je	pe64_entry_type_ok
	call	recoverable_invalid_address
      pe64_entry_type_ok:
	mov	ecx,[code_start]
	sub	eax,[ecx+30h]
	sbb	edx,[ecx+34h]
	jz	pe64_entry_range_ok
	call	recoverable_overflow
      pe64_entry_range_ok:
	mov	[ecx+28h],eax
	jmp	instruction_assembled
pe_stack:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	test	[format_flags],4
	jnz	peplus_stack
	call	get_count_value
	mov	edx,[code_start]
	mov	[edx+60h],eax
	cmp	byte [esi],','
	jne	default_stack_commit
	lods	byte [esi]
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	edx,[code_start]
	mov	[edx+64h],eax
	cmp	eax,[edx+60h]
	ja	value_out_of_range
	jmp	instruction_assembled
      default_stack_commit:
	mov	dword [edx+64h],1000h
	mov	eax,[edx+60h]
	cmp	eax,1000h
	ja	instruction_assembled
	mov	dword [edx+64h],eax
	jmp	instruction_assembled
      peplus_stack:
	call	get_qword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	ecx,[code_start]
	mov	[ecx+60h],eax
	mov	[ecx+64h],edx
	cmp	byte [esi],','
	jne	default_peplus_stack_commit
	lods	byte [esi]
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_qword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	ecx,[code_start]
	mov	[ecx+68h],eax
	mov	[ecx+6Ch],edx
	cmp	edx,[ecx+64h]
	ja	value_out_of_range
	jb	instruction_assembled
	cmp	eax,[ecx+60h]
	ja	value_out_of_range
	jmp	instruction_assembled
      default_peplus_stack_commit:
	mov	dword [ecx+68h],1000h
	cmp	dword [ecx+64h],0
	jne	instruction_assembled
	mov	eax,[ecx+60h]
	cmp	eax,1000h
	ja	instruction_assembled
	mov	dword [ecx+68h],eax
	jmp	instruction_assembled
pe_heap:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	test	[format_flags],4
	jnz	peplus_heap
	call	get_count_value
	mov	edx,[code_start]
	mov	[edx+68h],eax
	cmp	byte [esi],','
	jne	instruction_assembled
	lods	byte [esi]
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_count_value
	mov	edx,[code_start]
	mov	[edx+6Ch],eax
	cmp	eax,[edx+68h]
	ja	value_out_of_range
	jmp	instruction_assembled
      peplus_heap:
	call	get_qword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	ecx,[code_start]
	mov	[ecx+70h],eax
	mov	[ecx+74h],edx
	cmp	byte [esi],','
	jne	instruction_assembled
	lods	byte [esi]
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_qword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	ecx,[code_start]
	mov	[ecx+78h],eax
	mov	[ecx+7Ch],edx
	cmp	edx,[ecx+74h]
	ja	value_out_of_range
	jb	instruction_assembled
	cmp	eax,[ecx+70h]
	ja	value_out_of_range
	jmp	instruction_assembled
mark_pe_relocation:
	push	eax ebx
	test	[format_flags],4
	jz	check_standard_pe_relocation_type
	cmp	[value_type],4
	je	pe_relocation_type_ok
      check_standard_pe_relocation_type:
	cmp	[value_type],2
	je	pe_relocation_type_ok
	call	recoverable_misuse
      pe_relocation_type_ok:
	mov	ebx,[current_section]
	mov	eax,edi
	sub	eax,[ebx+14h]
	add	eax,[ebx+0Ch]
	mov	ebx,[free_additional_memory]
	inc	[number_of_relocations]
	add	ebx,5
	cmp	ebx,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],ebx
	mov	[ebx-5],eax
	cmp	[value_type],2
	je	fixup_32bit
	mov	byte [ebx-1],0Ah
	jmp	fixup_ok
      fixup_32bit:
	mov	byte [ebx-1],3
      fixup_ok:
	pop	ebx eax
	ret
generate_pe_data:
	cmp	al,2
	je	make_pe_resource
	cmp	al,5
	je	make_pe_fixups
	ret
make_pe_fixups:
	mov	edx,[code_start]
	and	byte [edx+16h],not 1
	or	byte [edx+5Eh],40h
	bts	[resolver_flags],0
	jc	fixups_ready
	or	[next_pass_needed],-1
      fixups_ready:
	and	[last_fixup_base],0
	call	make_fixups
	xchg	eax,[actual_fixups_size]
	sub	eax,[actual_fixups_size]
	ja	reserve_forward_fixups
	xor	eax,eax
      reserve_forward_fixups:
	mov	[reserved_fixups],edi
	add	edi,eax
	mov	[reserved_fixups_size],eax
	ret
      make_fixups:
	push	esi
	xor	ecx,ecx
	xchg	ecx,[number_of_relocations]
	mov	esi,[free_additional_memory]
	lea	eax,[ecx*5]
	sub	esi,eax
	mov	[free_additional_memory],esi
	mov	edx,[last_fixup_base]
	mov	ebx,[last_fixup_header]
	mov	ebp,edi
	jecxz	fixups_done
      make_fixup:
	cmp	[esi],edx
	jb	store_fixup
	mov	eax,edi
	sub	eax,ebp
	test	eax,11b
	jz	fixups_block
	xor	ax,ax
	stos	word [edi]
	add	dword [ebx],2
      fixups_block:
	mov	eax,edx
	add	edx,1000h
	cmp	[esi],edx
	jae	fixups_block
	stos	dword [edi]
	mov	ebx,edi
	mov	eax,8
	stos	dword [edi]
      store_fixup:
	add	dword [ebx],2
	mov	ah,[esi+1]
	and	ah,0Fh
	mov	al,[esi+4]
	shl	al,4
	or	ah,al
	mov	al,[esi]
	stos	word [edi]
	add	esi,5
	loop	make_fixup
      fixups_done:
	mov	[last_fixup_base],edx
	mov	[last_fixup_header],ebx
	pop	esi
	mov	eax,edi
	sub	eax,ebp
	ret
make_pe_resource:
	cmp	byte [esi],82h
	jne	resource_done
	inc	esi
	lods	word [esi]
	cmp	ax,'('
	jne	invalid_argument
	lods	dword [esi]
	mov	edx,esi
	lea	esi,[esi+eax+1]
	cmp	[next_pass_needed],0
	je	resource_from_file
	cmp	[current_pass],0
	jne	reserve_space_for_resource
	and	[resource_size],0
      reserve_space_for_resource:
	add	edi,[resource_size]
	cmp	edi,[tagged_blocks]
	ja	out_of_memory
	jmp	resource_done
      resource_from_file:
	push	esi
	mov	esi,edx
	call	open_binary_file
	push	ebx
	mov	esi,[free_additional_memory]
	lea	eax,[esi+20h]
	cmp	eax,[structures_buffer]
	ja	out_of_memory
	mov	edx,esi
	mov	ecx,20h
	call	read
	jc	invalid_file_format
	xor	eax,eax
	cmp	[esi],eax
	jne	invalid_file_format
	mov	ax,0FFFFh
	cmp	[esi+8],eax
	jne	invalid_file_format
	cmp	[esi+12],eax
	jne	invalid_file_format
	mov	eax,20h
	cmp	[esi+4],eax
	jne	invalid_file_format
      read_resource_headers:
	test	eax,11b
	jz	resource_file_alignment_ok
	mov	edx,4
	and	eax,11b
	sub	edx,eax
	mov	al,1
	call	lseek
      resource_file_alignment_ok:
	mov	[esi],eax
	lea	edx,[esi+12]
	mov	ecx,8
	call	read
	jc	resource_headers_ok
	mov	ecx,[esi+16]
	add	[esi],ecx
	lea	edx,[esi+20]
	sub	ecx,8
	mov	[esi+16],ecx
	lea	eax,[edx+ecx]
	cmp	eax,[structures_buffer]
	ja	out_of_memory
	call	read
	jc	invalid_file_format
	mov	edx,[esi]
	add	edx,[esi+12]
	mov	eax,[esi+16]
	lea	ecx,[esi+20]
	lea	esi,[ecx+eax]
	add	ecx,2
	cmp	word [ecx-2],0FFFFh
	je	resource_header_type_ok
      check_resource_header_type:
	cmp	ecx,esi
	jae	invalid_file_format
	cmp	word [ecx],0
	je	resource_header_type_ok
	add	ecx,2
	jmp	check_resource_header_type
      resource_header_type_ok:
	add	ecx,2
	cmp	word [ecx],0FFFFh
	je	resource_header_name_ok
      check_resource_header_name:
	cmp	ecx,esi
	jae	invalid_file_format
	cmp	word [ecx],0
	je	resource_header_name_ok
	add	ecx,2
	jmp	check_resource_header_name
      resource_header_name_ok:
	xor	al,al
	call	lseek
	jmp	read_resource_headers
      resource_headers_ok:
	xor	eax,eax
	mov	[esi],eax
	mov	[resource_data],edi
	lea	eax,[edi+16]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	xor	eax,eax
	stos	dword [edi]
	call	make_timestamp
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	xor	ebx,ebx
      make_type_name_directory:
	mov	esi,[free_additional_memory]
	xor	edx,edx
      find_type_name:
	cmp	dword [esi],0
	je	type_name_ok
	add	esi,20
	cmp	word [esi],0FFFFh
	je	check_next_type_name
	or	ebx,ebx
	jz	check_this_type_name
	xor	ecx,ecx
      compare_with_previous_type_name:
	mov	ax,[esi+ecx]
	cmp	ax,[ebx+ecx]
	ja	check_this_type_name
	jb	check_next_type_name
	add	ecx,2
	mov	ax,[esi+ecx]
	or	ax,[ebx+ecx]
	jnz	compare_with_previous_type_name
	jmp	check_next_type_name
      check_this_type_name:
	or	edx,edx
	jz	type_name_found
	xor	ecx,ecx
      compare_with_current_type_name:
	mov	ax,[esi+ecx]
	cmp	ax,[edx+ecx]
	ja	check_next_type_name
	jb	type_name_found
	add	ecx,2
	mov	ax,[esi+ecx]
	or	ax,[edx+ecx]
	jnz	compare_with_current_type_name
	jmp	same_type_name
      type_name_found:
	mov	edx,esi
      same_type_name:
	mov	[esi-16],edi
      check_next_type_name:
	mov	eax,[esi-4]
	add	esi,eax
	jmp	find_type_name
      type_name_ok:
	or	edx,edx
	jz	type_name_directory_done
	mov	ebx,edx
      make_type_name_entry:
	mov	eax,[resource_data]
	inc	word [eax+12]
	lea	eax,[edi+8]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	mov	eax,ebx
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	jmp	make_type_name_directory
      type_name_directory_done:
	mov	ebx,-1
      make_type_id_directory:
	mov	esi,[free_additional_memory]
	mov	edx,10000h
      find_type_id:
	cmp	dword [esi],0
	je	type_id_ok
	add	esi,20
	cmp	word [esi],0FFFFh
	jne	check_next_type_id
	movzx	eax,word [esi+2]
	cmp	eax,ebx
	jle	check_next_type_id
	cmp	eax,edx
	jg	check_next_type_id
	mov	edx,eax
	mov	[esi-16],edi
      check_next_type_id:
	mov	eax,[esi-4]
	add	esi,eax
	jmp	find_type_id
      type_id_ok:
	cmp	edx,10000h
	je	type_id_directory_done
	mov	ebx,edx
      make_type_id_entry:
	mov	eax,[resource_data]
	inc	word [eax+14]
	lea	eax,[edi+8]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	mov	eax,ebx
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	jmp	make_type_id_directory
      type_id_directory_done:
	mov	esi,[resource_data]
	add	esi,10h
	mov	ecx,[esi-4]
	or	cx,cx
	jz	resource_directories_ok
      make_resource_directories:
	push	ecx
	push	edi
	mov	edx,edi
	sub	edx,[resource_data]
	bts	edx,31
	mov	[esi+4],edx
	lea	eax,[edi+16]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	xor	eax,eax
	stos	dword [edi]
	call	make_timestamp
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	mov	ebp,esi
	xor	ebx,ebx
      make_resource_name_directory:
	mov	esi,[free_additional_memory]
	xor	edx,edx
      find_resource_name:
	cmp	dword [esi],0
	je	resource_name_ok
	push	esi
	cmp	[esi+4],ebp
	jne	check_next_resource_name
	add	esi,20
	call	skip_resource_name
	cmp	word [esi],0FFFFh
	je	check_next_resource_name
	or	ebx,ebx
	jz	check_this_resource_name
	xor	ecx,ecx
      compare_with_previous_resource_name:
	mov	ax,[esi+ecx]
	cmp	ax,[ebx+ecx]
	ja	check_this_resource_name
	jb	check_next_resource_name
	add	ecx,2
	mov	ax,[esi+ecx]
	or	ax,[ebx+ecx]
	jnz	compare_with_previous_resource_name
	jmp	check_next_resource_name
      skip_resource_name:
	cmp	word [esi],0FFFFh
	jne	skip_unicode_string
	add	esi,4
	ret
      skip_unicode_string:
	add	esi,2
	cmp	word [esi-2],0
	jne	skip_unicode_string
	ret
      check_this_resource_name:
	or	edx,edx
	jz	resource_name_found
	xor	ecx,ecx
      compare_with_current_resource_name:
	mov	ax,[esi+ecx]
	cmp	ax,[edx+ecx]
	ja	check_next_resource_name
	jb	resource_name_found
	add	ecx,2
	mov	ax,[esi+ecx]
	or	ax,[edx+ecx]
	jnz	compare_with_current_resource_name
	jmp	same_resource_name
      resource_name_found:
	mov	edx,esi
      same_resource_name:
	mov	eax,[esp]
	mov	[eax+8],edi
      check_next_resource_name:
	pop	esi
	mov	eax,[esi+16]
	lea	esi,[esi+20+eax]
	jmp	find_resource_name
      resource_name_ok:
	or	edx,edx
	jz	resource_name_directory_done
	mov	ebx,edx
      make_resource_name_entry:
	mov	eax,[esp]
	inc	word [eax+12]
	lea	eax,[edi+8]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	mov	eax,ebx
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	jmp	make_resource_name_directory
      resource_name_directory_done:
	mov	ebx,-1
      make_resource_id_directory:
	mov	esi,[free_additional_memory]
	mov	edx,10000h
      find_resource_id:
	cmp	dword [esi],0
	je	resource_id_ok
	push	esi
	cmp	[esi+4],ebp
	jne	check_next_resource_id
	add	esi,20
	call	skip_resource_name
	cmp	word [esi],0FFFFh
	jne	check_next_resource_id
	movzx	eax,word [esi+2]
	cmp	eax,ebx
	jle	check_next_resource_id
	cmp	eax,edx
	jg	check_next_resource_id
	mov	edx,eax
	mov	eax,[esp]
	mov	[eax+8],edi
      check_next_resource_id:
	pop	esi
	mov	eax,[esi+16]
	lea	esi,[esi+20+eax]
	jmp	find_resource_id
      resource_id_ok:
	cmp	edx,10000h
	je	resource_id_directory_done
	mov	ebx,edx
      make_resource_id_entry:
	mov	eax,[esp]
	inc	word [eax+14]
	lea	eax,[edi+8]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	mov	eax,ebx
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	jmp	make_resource_id_directory
      resource_id_directory_done:
	pop	eax
	mov	esi,ebp
	pop	ecx
	add	esi,8
	dec	cx
	jnz	make_resource_directories
      resource_directories_ok:
	shr	ecx,16
	jnz	make_resource_directories
	mov	esi,[resource_data]
	add	esi,10h
	movzx	eax,word [esi-4]
	movzx	edx,word [esi-2]
	add	eax,edx
	lea	esi,[esi+eax*8]
	push	edi			# address of language directories
      update_resource_directories:
	cmp	esi,[esp]
	je	resource_directories_updated
	add	esi,10h
	mov	ecx,[esi-4]
	or	cx,cx
	jz	language_directories_ok
      make_language_directories:
	push	ecx
	push	edi
	mov	edx,edi
	sub	edx,[resource_data]
	bts	edx,31
	mov	[esi+4],edx
	lea	eax,[edi+16]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	xor	eax,eax
	stos	dword [edi]
	call	make_timestamp
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	mov	ebp,esi
	mov	ebx,-1
      make_language_id_directory:
	mov	esi,[free_additional_memory]
	mov	edx,10000h
      find_language_id:
	cmp	dword [esi],0
	je	language_id_ok
	push	esi
	cmp	[esi+8],ebp
	jne	check_next_language_id
	add	esi,20
	mov	eax,esi
	call	skip_resource_name
	call	skip_resource_name
	neg	eax
	add	eax,esi
	and	eax,11b
	add	esi,eax
      get_language_id:
	movzx	eax,word [esi+6]
	cmp	eax,ebx
	jle	check_next_language_id
	cmp	eax,edx
	jge	check_next_language_id
	mov	edx,eax
	mov	eax,[esp]
	mov	dword [value],eax
      check_next_language_id:
	pop	esi
	mov	eax,[esi+16]
	lea	esi,[esi+20+eax]
	jmp	find_language_id
      language_id_ok:
	cmp	edx,10000h
	je	language_id_directory_done
	mov	ebx,edx
      make_language_id_entry:
	mov	eax,[esp]
	inc	word [eax+14]
	lea	eax,[edi+8]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	mov	eax,ebx
	stos	dword [edi]
	mov	eax,dword [value]
	stos	dword [edi]
	jmp	make_language_id_directory
      language_id_directory_done:
	pop	eax
	mov	esi,ebp
	pop	ecx
	add	esi,8
	dec	cx
	jnz	make_language_directories
      language_directories_ok:
	shr	ecx,16
	jnz	make_language_directories
	jmp	update_resource_directories
      resource_directories_updated:
	mov	esi,[resource_data]
	push	edi
      make_name_strings:
	add	esi,10h
	movzx	eax,word [esi-2]
	movzx	ecx,word [esi-4]
	add	eax,ecx
	lea	eax,[esi+eax*8]
	push	eax
	or	ecx,ecx
	jz	string_entries_processed
      process_string_entries:
	push	ecx
	mov	edx,edi
	sub	edx,[resource_data]
	bts	edx,31
	xchg	[esi],edx
	mov	ebx,edi
	xor	ax,ax
	stos	word [edi]
      copy_string_data:
	lea	eax,[edi+2]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	mov	ax,[edx]
	or	ax,ax
	jz	string_data_copied
	stos	word [edi]
	inc	word [ebx]
	add	edx,2
	jmp	copy_string_data
      string_data_copied:
	add	esi,8
	pop	ecx
	loop	process_string_entries
      string_entries_processed:
	pop	esi
	cmp	esi,[esp]
	jb	make_name_strings
	mov	eax,edi
	sub	eax,[resource_data]
	test	al,11b
	jz	resource_strings_alignment_ok
	xor	ax,ax
	stos	word [edi]
      resource_strings_alignment_ok:
	pop	edx
	pop	ebx			# address of language directories
	mov	ebp,edi
      update_language_directories:
	add	ebx,10h
	movzx	eax,word [ebx-2]
	movzx	ecx,word [ebx-4]
	add	ecx,eax
      make_data_records:
	push	ecx
	mov	esi,edi
	sub	esi,[resource_data]
	xchg	esi,[ebx+4]
	lea	eax,[edi+16]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	mov	eax,esi
	stos	dword [edi]
	mov	eax,[esi+12]
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	pop	ecx
	add	ebx,8
	loop	make_data_records
	cmp	ebx,edx
	jb	update_language_directories
	pop	ebx			# file handle
	mov	esi,ebp
	mov	ebp,edi
      update_data_records:
	push	ebp
	mov	ecx,edi
	mov	eax,[current_section]
	sub	ecx,[eax+14h]
	add	ecx,[eax+0Ch]
	xchg	ecx,[esi]
	mov	edx,[ecx]
	xor	al,al
	call	lseek
	mov	edx,edi
	mov	ecx,[esi+4]
	add	edi,ecx
	cmp	edi,[tagged_blocks]
	ja	out_of_memory
	call	read
	mov	eax,edi
	sub	eax,[resource_data]
	and	eax,11b
	jz	resource_data_alignment_ok
	mov	ecx,4
	sub	ecx,eax
	xor	al,al
	rep	stos byte [edi]
      resource_data_alignment_ok:
	pop	ebp
	add	esi,16
	cmp	esi,ebp
	jb	update_data_records
	pop	esi
	call	close
	mov	eax,edi
	sub	eax,[resource_data]
	mov	[resource_size],eax
      resource_done:
	ret
close_pe:
	call	close_pe_section
	mov	edx,[code_start]
	mov	[edx+50h],eax
	call	make_timestamp
	mov	edx,[code_start]
	mov	[edx+8],eax
	mov	eax,[number_of_sections]
	mov	[edx+6],ax
	imul	eax,28h
	movzx	ecx,word [edx+14h]
	lea	eax,[eax+18h+ecx]
	add	eax,[stub_size]
	mov	ecx,[edx+3Ch]
	dec	ecx
	add	eax,ecx
	not	ecx
	and	eax,ecx
	cmp	eax,[edx+54h]
	je	pe_sections_ok
	or	[next_pass_needed],-1
      pe_sections_ok:
	xor	ecx,ecx
	add	edx,78h
	test	[format_flags],4
	jz	process_directories
	add	edx,10h
      process_directories:
	mov	eax,[edx+ecx*8]
	or	eax,eax
	jz	directory_ok
	cmp	dword [edx+ecx*8+4],-1
	jne	directory_ok
      section_data:
	mov	ebx,[edx+ecx*8]
	mov	eax,[ebx+0Ch]
	mov	[edx+ecx*8],eax 	# directory rva
	mov	eax,[ebx+8]
	mov	[edx+ecx*8+4],eax	# directory size
      directory_ok:
	inc	cl
	cmp	cl,10h
	jb	process_directories
	cmp	dword [edx+5*8],0
	jne	finish_pe_relocations
	mov	eax,[number_of_relocations]
	shl	eax,2
	sub	[free_additional_memory],eax
	btr	[resolver_flags],0
	jnc	pe_relocations_ok
	or	[next_pass_needed],-1
	jmp	pe_relocations_ok
      finish_pe_relocations:
	push	edi
	mov	edi,[reserved_fixups]
	call	make_fixups
	pop	edi
	add	[actual_fixups_size],eax
	cmp	eax,[reserved_fixups_size]
	je	pe_relocations_ok
	or	[next_pass_needed],-1
      pe_relocations_ok:
	mov	ebx,[code_start]
	sub	ebx,[stub_size]
	mov	ecx,edi
	sub	ecx,ebx
	mov	ebp,ecx
	shr	ecx,1
	xor	eax,eax
	cdq
      calculate_checksum:
	mov	dx,[ebx]
	add	eax,edx
	mov	dx,ax
	shr	eax,16
	add	eax,edx
	add	ebx,2
	loop	calculate_checksum
	add	eax,ebp
	mov	ebx,[code_start]
	mov	[ebx+58h],eax
	ret

format_coff:
	mov	eax,[additional_memory]
	mov	[symbols_stream],eax
	mov	ebx,eax
	add	eax,20h
	cmp	eax,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],eax
	xor	eax,eax
	mov	[ebx],al
	mov	[ebx+4],eax
	mov	[ebx+8],edi
	mov	al,4
	mov	[ebx+10h],eax
	mov	al,60h
	bt	[format_flags],0
	jnc	flat_section_flags_ok
	or	eax,0E0000000h
      flat_section_flags_ok:
	mov	dword [ebx+14h],eax
	mov	[current_section],ebx
	xor	eax,eax
	mov	[number_of_sections],eax
	mov	edx,ebx
	call	init_addressing_space
	mov	[ebx+14h],edx
	mov	byte [ebx+9],2
	mov	[code_type],32
	test	[format_flags],8
	jz	format_defined
	mov	byte [ebx+9],4
	mov	[code_type],64
	jmp	format_defined
coff_section:
	call	close_coff_section
	mov	ebx,[free_additional_memory]
	lea	eax,[ebx+20h]
	cmp	eax,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],eax
	mov	[current_section],ebx
	inc	[number_of_sections]
	xor	eax,eax
	mov	[ebx],al
	mov	[ebx+8],edi
	mov	[ebx+10h],eax
	mov	[ebx+14h],eax
	mov	edx,ebx
	call	create_addressing_space
	xchg	edx,ebx
	mov	[edx+14h],ebx
	mov	byte [edx+9],2
	test	[format_flags],8
	jz	coff_labels_type_ok
	mov	byte [edx+9],4
      coff_labels_type_ok:
	lods	word [esi]
	cmp	ax,'('
	jne	invalid_argument
	mov	[ebx+4],esi
	mov	ecx,[esi]
	lea	esi,[esi+4+ecx+1]
	cmp	ecx,8
	ja	name_too_long
      coff_section_flags:
	cmp	byte [esi],8Ch
	je	coff_section_alignment
	cmp	byte [esi],19h
	jne	coff_section_settings_ok
	inc	esi
	lods	byte [esi]
	bt	[format_flags],0
	jc	coff_section_flag_ok
	cmp	al,7
	ja	invalid_argument
      coff_section_flag_ok:
	mov	cl,al
	mov	eax,1
	shl	eax,cl
	test	dword [ebx+14h],eax
	jnz	setting_already_specified
	or	dword [ebx+14h],eax
	jmp	coff_section_flags
      coff_section_alignment:
	bt	[format_flags],0
	jnc	invalid_argument
	inc	esi
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	push	ebx
	call	get_count_value
	pop	ebx
	mov	edx,eax
	dec	edx
	test	eax,edx
	jnz	invalid_value
	or	eax,eax
	jz	invalid_value
	cmp	eax,2000h
	ja	invalid_value
	bsf	edx,eax
	inc	edx
	shl	edx,20
	or	[ebx+14h],edx
	xchg	[ebx+10h],eax
	or	eax,eax
	jnz	setting_already_specified
	jmp	coff_section_flags
      coff_section_settings_ok:
	cmp	dword [ebx+10h],0
	jne	instruction_assembled
	mov	dword [ebx+10h],4
	bt	[format_flags],0
	jnc	instruction_assembled
	or	dword [ebx+14h],300000h
	jmp	instruction_assembled
      close_coff_section:
	mov	ebx,[current_section]
	mov	eax,edi
	mov	edx,[ebx+8]
	sub	eax,edx
	mov	[ebx+0Ch],eax
	xor	eax,eax
	xchg	[undefined_data_end],eax
	cmp	eax,edi
	jne	coff_section_ok
	cmp	edx,[undefined_data_start]
	jne	coff_section_ok
	mov	edi,edx
	or	byte [ebx+14h],80h
      coff_section_ok:
	ret
mark_coff_relocation:
	cmp	[value_type],3
	je	coff_relocation_relative
	push	ebx eax
	test	[format_flags],8
	jnz	coff_64bit_relocation
	mov	al,6
	cmp	[value_type],2
	je	coff_relocation
	cmp	[value_type],5
	jne	invalid_use_of_symbol
	inc	al
	jmp	coff_relocation
      coff_64bit_relocation:
	mov	al,1
	cmp	[value_type],4
	je	coff_relocation
	mov	al,2
	cmp	[value_type],2
	je	coff_relocation
	cmp	[value_type],5
	jne	invalid_use_of_symbol
	inc	al
	jmp	coff_relocation
      coff_relocation_relative:
	push	ebx
	bt	[format_flags],0
	jnc	relative_ok
	mov	ebx,[current_section]
	mov	ebx,[ebx+8]
	sub	ebx,edi
	sub	eax,ebx
	add	eax,4
      relative_ok:
	mov	ebx,[addressing_space]
	push	eax
	mov	al,20
	test	[format_flags],8
	jnz	relative_coff_64bit_relocation
	cmp	byte [ebx+9],2
	jne	invalid_use_of_symbol
	jmp	coff_relocation
      relative_coff_64bit_relocation:
	mov	al,4
	cmp	byte [ebx+9],4
	jne	invalid_use_of_symbol
      coff_relocation:
	mov	ebx,[free_additional_memory]
	add	ebx,0Ch
	cmp	ebx,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],ebx
	mov	byte [ebx-0Ch],al
	mov	eax,[current_section]
	mov	eax,[eax+8]
	neg	eax
	add	eax,edi
	mov	[ebx-0Ch+4],eax
	mov	eax,[symbol_identifier]
	mov	[ebx-0Ch+8],eax
	pop	eax ebx
	ret
close_coff:
	call	close_coff_section
	cmp	[next_pass_needed],0
	je	coff_closed
	mov	eax,[symbols_stream]
	mov	[free_additional_memory],eax
      coff_closed:
	ret
coff_formatter:
	sub	edi,[code_start]
	mov	[code_size],edi
	call	prepare_default_section
	mov	edi,[free_additional_memory]
	mov	ebx,edi
	mov	ecx,28h shr 2
	imul	ecx,[number_of_sections]
	add	ecx,14h shr 2
	lea	eax,[edi+ecx*4]
	cmp	eax,[structures_buffer]
	jae	out_of_memory
	xor	eax,eax
	rep	stos dword [edi]
	mov	word [ebx],14Ch
	test	[format_flags],8
	jz	coff_magic_ok
	mov	word [ebx],8664h
      coff_magic_ok:
	mov	word [ebx+12h],104h
	bt	[format_flags],0
	jnc	coff_flags_ok
	or	byte [ebx+12h],80h
      coff_flags_ok:
	push	ebx
	call	make_timestamp
	pop	ebx
	mov	[ebx+4],eax
	mov	eax,[number_of_sections]
	mov	[ebx+2],ax
	mov	esi,[symbols_stream]
	xor	eax,eax
	xor	ecx,ecx
      enumerate_symbols:
	cmp	esi,[free_additional_memory]
	je	symbols_enumerated
	mov	dl,[esi]
	or	dl,dl
	jz	enumerate_section
	cmp	dl,0C0h
	jae	enumerate_public
	cmp	dl,80h
	jae	enumerate_extrn
	add	esi,0Ch
	jmp	enumerate_symbols
      enumerate_section:
	mov	edx,eax
	shl	edx,8
	mov	[esi],edx
	inc	eax
	inc	ecx
	mov	[esi+1Eh],cx
	add	esi,20h
	jmp	enumerate_symbols
      enumerate_public:
	mov	edx,eax
	shl	edx,8
	mov	dl,[esi]
	mov	[esi],edx
	mov	edx,[esi+8]
	add	esi,10h
	inc	eax
	cmp	byte [edx+11],0
	je	enumerate_symbols
	mov	edx,[edx+20]
	cmp	byte [edx],0C0h
	jae	enumerate_symbols
	cmp	byte [edx],80h
	jb	enumerate_symbols
	inc	eax
	jmp	enumerate_symbols
      enumerate_extrn:
	mov	edx,eax
	shl	edx,8
	mov	dl,[esi]
	mov	[esi],edx
	add	esi,0Ch
	inc	eax
	jmp	enumerate_symbols
      prepare_default_section:
	mov	ebx,[symbols_stream]
	cmp	dword [ebx+0Ch],0
	jne	default_section_ok
	cmp	[number_of_sections],0
	je	default_section_ok
	mov	edx,ebx
      find_references_to_default_section:
	cmp	ebx,[free_additional_memory]
	jne	check_reference
	add	[symbols_stream],20h
	ret
      check_reference:
	mov	al,[ebx]
	or	al,al
	jz	skip_other_section
	cmp	al,0C0h
	jae	check_public_reference
	cmp	al,80h
	jae	next_reference
	cmp	edx,[ebx+8]
	je	default_section_ok
      next_reference:
	add	ebx,0Ch
	jmp	find_references_to_default_section
      check_public_reference:
	mov	eax,[ebx+8]
	add	ebx,10h
	test	byte [eax+8],1
	jz	find_references_to_default_section
	mov	cx,[current_pass]
	cmp	cx,[eax+16]
	jne	find_references_to_default_section
	cmp	edx,[eax+20]
	je	default_section_ok
	jmp	find_references_to_default_section
      skip_other_section:
	add	ebx,20h
	jmp	find_references_to_default_section
      default_section_ok:
	inc	[number_of_sections]
	ret
      symbols_enumerated:
	mov	[ebx+0Ch],eax
	mov	ebp,edi
	sub	ebp,ebx
	push	ebp
	lea	edi,[ebx+14h]
	mov	esi,[symbols_stream]
      find_section:
	cmp	esi,[free_additional_memory]
	je	sections_finished
	mov	al,[esi]
	or	al,al
	jz	section_found
	add	esi,0Ch
	cmp	al,0C0h
	jb	find_section
	add	esi,4
	jmp	find_section
      section_found:
	push	esi edi
	mov	esi,[esi+4]
	or	esi,esi
	jz	default_section
	mov	ecx,[esi]
	add	esi,4
	rep	movs byte [edi],[esi]
	jmp	section_name_ok
      default_section:
	mov	al,'.'
	stos	byte [edi]
	mov	eax,'flat'
	stos	dword [edi]
      section_name_ok:
	pop	edi esi
	mov	eax,[esi+0Ch]
	mov	[edi+10h],eax
	mov	eax,[esi+14h]
	mov	[edi+24h],eax
	test	al,80h
	jnz	section_ptr_ok
	mov	eax,[esi+8]
	sub	eax,[code_start]
	add	eax,ebp
	mov	[edi+14h],eax
      section_ptr_ok:
	mov	ebx,[code_start]
	mov	edx,[code_size]
	add	ebx,edx
	add	edx,ebp
	xor	ecx,ecx
	add	esi,20h
      find_relocations:
	cmp	esi,[free_additional_memory]
	je	section_relocations_done
	mov	al,[esi]
	or	al,al
	jz	section_relocations_done
	cmp	al,80h
	jb	add_relocation
	cmp	al,0C0h
	jb	next_relocation
	add	esi,10h
	jmp	find_relocations
      add_relocation:
	lea	eax,[ebx+0Ah]
	cmp	eax,[tagged_blocks]
	ja	out_of_memory
	mov	eax,[esi+4]
	mov	[ebx],eax
	mov	eax,[esi+8]
	mov	eax,[eax]
	shr	eax,8
	mov	[ebx+4],eax
	movzx	ax,byte [esi]
	mov	[ebx+8],ax
	add	ebx,0Ah
	inc	ecx
      next_relocation:
	add	esi,0Ch
	jmp	find_relocations
      section_relocations_done:
	cmp	ecx,10000h
	jb	section_relocations_count_16bit
	bt	[format_flags],0
	jnc	format_limitations_exceeded
	mov	word [edi+20h],0FFFFh
	or	dword [edi+24h],1000000h
	mov	[edi+18h],edx
	push	esi edi
	push	ecx
	lea	esi,[ebx-1]
	add	ebx,0Ah
	lea	edi,[ebx-1]
	imul	ecx,0Ah
	std
	rep	movs byte [edi],[esi]
	cld
	pop	ecx
	inc	esi
	inc	ecx
	mov	[esi],ecx
	xor	eax,eax
	mov	[esi+4],eax
	mov	[esi+8],ax
	pop	edi esi
	jmp	section_relocations_ok
      section_relocations_count_16bit:
	mov	[edi+20h],cx
	jcxz	section_relocations_ok
	mov	[edi+18h],edx
      section_relocations_ok:
	sub	ebx,[code_start]
	mov	[code_size],ebx
	add	edi,28h
	jmp	find_section
      sections_finished:
	mov	edx,[free_additional_memory]
	mov	ebx,[code_size]
	add	ebp,ebx
	mov	[edx+8],ebp
	add	ebx,[code_start]
	mov	edi,ebx
	mov	ecx,[edx+0Ch]
	imul	ecx,12h shr 1
	xor	eax,eax
	shr	ecx,1
	jnc	zero_symbols_table
	stos	word [edi]
      zero_symbols_table:
	rep	stos dword [edi]
	mov	edx,edi
	stos	dword [edi]
	mov	esi,[symbols_stream]
      make_symbols_table:
	cmp	esi,[free_additional_memory]
	je	symbols_table_ok
	mov	al,[esi]
	cmp	al,0C0h
	jae	add_public_symbol
	cmp	al,80h
	jae	add_extrn_symbol
	or	al,al
	jz	add_section_symbol
	add	esi,0Ch
	jmp	make_symbols_table
      add_section_symbol:
	call	store_symbol_name
	movzx	eax,word [esi+1Eh]
	mov	[ebx+0Ch],ax
	mov	byte [ebx+10h],3
	add	esi,20h
	add	ebx,12h
	jmp	make_symbols_table
      add_extrn_symbol:
	call	store_symbol_name
	mov	byte [ebx+10h],2
	add	esi,0Ch
	add	ebx,12h
	jmp	make_symbols_table
      add_public_symbol:
	call	store_symbol_name
	mov	eax,[esi+0Ch]
	mov	[current_line],eax
	mov	eax,[esi+8]
	test	byte [eax+8],1
	jz	undefined_coff_public
	mov	cx,[current_pass]
	cmp	cx,[eax+16]
	jne	undefined_coff_public
	mov	cl,[eax+11]
	or	cl,cl
	jz	public_constant
	test	[format_flags],8
	jnz	check_64bit_public_symbol
	cmp	cl,2
	je	public_symbol_type_ok
	jmp	invalid_use_of_symbol
      undefined_coff_public:
	mov	[error_info],eax
	jmp	undefined_symbol
      check_64bit_public_symbol:
	cmp	cl,4
	jne	invalid_use_of_symbol
      public_symbol_type_ok:
	mov	ecx,[eax+20]
	cmp	byte [ecx],80h
	je	alias_symbol
	cmp	byte [ecx],0
	jne	invalid_use_of_symbol
	mov	cx,[ecx+1Eh]
	mov	[ebx+0Ch],cx
      public_symbol_section_ok:
	movzx	ecx,byte [eax+9]
	shr	cl,1
	and	cl,1
	neg	ecx
	cmp	ecx,[eax+4]
	jne	value_out_of_range
	xor	ecx,[eax]
	js	value_out_of_range
	mov	eax,[eax]
	mov	[ebx+8],eax
	mov	al,2
	cmp	byte [esi],0C0h
	je	store_symbol_class
	inc	al
	cmp	byte [esi],0C1h
	je	store_symbol_class
	mov	al,105
      store_symbol_class:
	mov	byte [ebx+10h],al
	add	esi,10h
	add	ebx,12h
	jmp	make_symbols_table
      alias_symbol:
	bt	[format_flags],0
	jnc	invalid_use_of_symbol
	mov	ecx,[eax]
	or	ecx,[eax+4]
	jnz	invalid_use_of_symbol
	mov	byte [ebx+10h],69h
	mov	byte [ebx+11h],1
	add	ebx,12h
	mov	ecx,[eax+20]
	mov	ecx,[ecx]
	shr	ecx,8
	mov	[ebx],ecx
	mov	byte [ebx+4],3
	add	esi,10h
	add	ebx,12h
	jmp	make_symbols_table
      public_constant:
	mov	word [ebx+0Ch],0FFFFh
	jmp	public_symbol_section_ok
      symbols_table_ok:
	mov	eax,edi
	sub	eax,edx
	mov	[edx],eax
	sub	edi,[code_start]
	mov	[code_size],edi
	and	[written_size],0
	mov	edx,[output_file]
	call	create
	jc	write_failed
	mov	edx,[free_additional_memory]
	pop	ecx
	add	[written_size],ecx
	call	write
	jc	write_failed
	jmp	write_output
      store_symbol_name:
	push	esi
	mov	esi,[esi+4]
	or	esi,esi
	jz	default_name
	lods	dword [esi]
	mov	ecx,eax
	cmp	ecx,8
	ja	add_string
	push	edi
	mov	edi,ebx
	rep	movs byte [edi],[esi]
	pop	edi esi
	ret
      default_name:
	mov	dword [ebx],'.fla'
	mov	dword [ebx+4],'t'
	pop	esi
	ret
      add_string:
	mov	eax,edi
	sub	eax,edx
	mov	[ebx+4],eax
	inc	ecx
	rep	movs byte [edi],[esi]
	pop	esi
	ret

format_elf:
	test	[format_flags],8
	jnz	format_elf64
	mov	edx,edi
	mov	ecx,34h shr 2
	lea	eax,[edi+ecx*4]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	xor	eax,eax
	rep	stos dword [edi]
	mov	dword [edx],7Fh + 'ELF' shl 8
	mov	al,1
	mov	[edx+4],al
	mov	[edx+5],al
	mov	[edx+6],al
	mov	[edx+14h],al
	mov	byte [edx+12h],3
	mov	byte [edx+28h],34h
	mov	byte [edx+2Eh],28h
	mov	[code_type],32
	cmp	word [esi],1D19h
	je	format_elf_exe
      elf_header_ok:
	mov	byte [edx+10h],1
	mov	eax,[additional_memory]
	mov	[symbols_stream],eax
	mov	ebx,eax
	add	eax,20h
	cmp	eax,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],eax
	xor	eax,eax
	mov	[current_section],ebx
	mov	[number_of_sections],eax
	mov	[ebx],al
	mov	[ebx+4],eax
	mov	[ebx+8],edi
	mov	al,111b
	mov	[ebx+14h],eax
	mov	al,4
	mov	[ebx+10h],eax
	mov	edx,ebx
	call	init_addressing_space
	xchg	edx,ebx
	mov	[edx+14h],ebx
	mov	byte [edx+9],2
	test	[format_flags],8
	jz	format_defined
	mov	byte [edx+9],4
	mov	byte [ebx+10h],8
	jmp	format_defined
      format_elf64:
	mov	edx,edi
	mov	ecx,40h shr 2
	lea	eax,[edi+ecx*4]
	cmp	eax,[tagged_blocks]
	jae	out_of_memory
	xor	eax,eax
	rep	stos dword [edi]
	mov	dword [edx],7Fh + 'ELF' shl 8
	mov	al,1
	mov	[edx+5],al
	mov	[edx+6],al
	mov	[edx+14h],al
	mov	byte [edx+4],2
	mov	byte [edx+12h],62
	mov	byte [edx+34h],40h
	mov	byte [edx+3Ah],40h
	mov	[code_type],64
	cmp	word [esi],1D19h
	jne	elf_header_ok
	jmp	format_elf64_exe
elf_section:
	bt	[format_flags],0
	jc	illegal_instruction
	call	close_coff_section
	mov	ebx,[free_additional_memory]
	lea	eax,[ebx+20h]
	cmp	eax,[structures_buffer]
	jae	out_of_memory
	mov	[free_additional_memory],eax
	mov	[current_section],ebx
	inc	word [number_of_sections]
	jz	format_limitations_exceeded
	xor	eax,eax
	mov	[ebx],al
	mov	[ebx+8],edi
	mov	[ebx+10h],eax
	mov	al,10b
	mov	[ebx+14h],eax
	mov	edx,ebx
	call	create_addressing_space
	xchg	edx,ebx
	mov	[edx+14h],ebx
	mov	byte [edx+9],2
	test	[format_flags],8
	jz	elf_labels_type_ok
	mov	byte [edx+9],4
      elf_labels_type_ok:
	lods	word [esi]
	cmp	ax,'('
	jne	invalid_argument
	mov	[ebx+4],esi
	mov	ecx,[esi]
	lea	esi,[esi+4+ecx+1]
      elf_section_flags:
	cmp	byte [esi],8Ch
	je	elf_section_alignment
	cmp	byte [esi],19h
	jne	elf_section_settings_ok
	inc	esi
	lods	byte [esi]
	sub	al,28
	xor	al,11b
	test	al,not 10b
	jnz	invalid_argument
	mov	cl,al
	mov	al,1
	shl	al,cl
	test	byte [ebx+14h],al
	jnz	setting_already_specified
	or	byte [ebx+14h],al
	jmp	elf_section_flags
      elf_section_alignment:
	inc	esi
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	push	ebx
	call	get_count_value
	pop	ebx
	mov	edx,eax
	dec	edx
	test	eax,edx
	jnz	invalid_value
	or	eax,eax
	jz	invalid_value
	xchg	[ebx+10h],eax
	or	eax,eax
	jnz	setting_already_specified
	jmp	elf_section_flags
      elf_section_settings_ok:
	cmp	dword [ebx+10h],0
	jne	instruction_assembled
	mov	dword [ebx+10h],4
	test	[format_flags],8
	jz	instruction_assembled
	mov	byte [ebx+10h],8
	jmp	instruction_assembled
mark_elf_relocation:
	push	ebx
	mov	ebx,[addressing_space]
	cmp	[value_type],3
	je	elf_relocation_relative
	cmp	[value_type],7
	je	elf_relocation_relative
	push	eax
	cmp	[value_type],5
	je	elf_gotoff_relocation
	ja	invalid_use_of_symbol
	mov	al,1			# R_386_32 / R_AMD64_64
	test	[format_flags],8
	jz	coff_relocation
	cmp	[value_type],4
	je	coff_relocation
	mov	al,11			# R_AMD64_32S
	jmp	coff_relocation
      elf_gotoff_relocation:
	test	[format_flags],8
	jnz	invalid_use_of_symbol
	mov	al,9			# R_386_GOTOFF
	jmp	coff_relocation
      elf_relocation_relative:
	cmp	byte [ebx+9],0
	je	invalid_use_of_symbol
	mov	ebx,[current_section]
	mov	ebx,[ebx+8]
	sub	ebx,edi
	sub	eax,ebx
	push	eax
	mov	al,2			# R_386_PC32 / R_AMD64_PC32
	cmp	[value_type],3
	je	coff_relocation
	mov	al,4			# R_386_PLT32 / R_AMD64_PLT32
	jmp	coff_relocation
close_elf:
	bt	[format_flags],0
	jc	close_elf_exe
	call	close_coff_section
	cmp	[next_pass_needed],0
	je	elf_closed
	mov	eax,[symbols_stream]
	mov	[free_additional_memory],eax
      elf_closed:
	ret
elf_formatter:
	push	edi
	call	prepare_default_section
	mov	esi,[symbols_stream]
	mov	edi,[free_additional_memory]
	xor	eax,eax
	mov	ecx,4
	rep	stos dword [edi]
	test	[format_flags],8
	jz	find_first_section
	mov	ecx,2
	rep	stos dword [edi]
      find_first_section:
	mov	al,[esi]
	or	al,al
	jz	first_section_found
	cmp	al,0C0h
	jb	skip_other_symbol
	add	esi,4
      skip_other_symbol:
	add	esi,0Ch
	jmp	find_first_section
      first_section_found:
	mov	ebx,esi
	mov	ebp,esi
	add	esi,20h
	xor	ecx,ecx
	xor	edx,edx
      find_next_section:
	cmp	esi,[free_additional_memory]
	je	make_section_symbol
	mov	al,[esi]
	or	al,al
	jz	make_section_symbol
	cmp	al,0C0h
	jae	skip_public
	cmp	al,80h
	jae	skip_extrn
	or	byte [ebx+14h],40h
      skip_extrn:
	add	esi,0Ch
	jmp	find_next_section
      skip_public:
	add	esi,10h
	jmp	find_next_section
      make_section_symbol:
	mov	eax,edi
	xchg	eax,[ebx+4]
	stos	dword [edi]
	test	[format_flags],8
	jnz	elf64_section_symbol
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	call	store_section_index
	jmp	section_symbol_ok
      store_section_index:
	inc	ecx
	mov	eax,ecx
	shl	eax,8
	mov	[ebx],eax
	inc	dx
	jz	format_limitations_exceeded
	mov	eax,edx
	shl	eax,16
	mov	al,3
	test	byte [ebx+14h],40h
	jz	section_index_ok
	or	ah,-1
	inc	dx
	jz	format_limitations_exceeded
      section_index_ok:
	stos	dword [edi]
	ret
      elf64_section_symbol:
	call	store_section_index
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	stos	dword [edi]
	stos	dword [edi]
      section_symbol_ok:
	mov	ebx,esi
	add	esi,20h
	cmp	ebx,[free_additional_memory]
	jne	find_next_section
	inc	dx
	jz	format_limitations_exceeded
	mov	[current_section],edx
	mov	esi,[symbols_stream]
      find_other_symbols:
	cmp	esi,[free_additional_memory]
	je	elf_symbol_table_ok
	mov	al,[esi]
	or	al,al
	jz	skip_section
	cmp	al,0C0h
	jae	make_public_symbol
	cmp	al,80h
	jae	make_extrn_symbol
	add	esi,0Ch
	jmp	find_other_symbols
      skip_section:
	add	esi,20h
	jmp	find_other_symbols
      make_public_symbol:
	mov	eax,[esi+0Ch]
	mov	[current_line],eax
	cmp	byte [esi],0C0h
	jne	invalid_argument
	mov	ebx,[esi+8]
	test	byte [ebx+8],1
	jz	undefined_public
	mov	ax,[current_pass]
	cmp	ax,[ebx+16]
	jne	undefined_public
	mov	dl,[ebx+11]
	or	dl,dl
	jz	public_absolute
	mov	eax,[ebx+20]
	cmp	byte [eax],0
	jne	invalid_use_of_symbol
	mov	eax,[eax+4]
	test	[format_flags],8
	jnz	elf64_public
	cmp	dl,2
	jne	invalid_use_of_symbol
	mov	dx,[eax+0Eh]
	jmp	section_for_public_ok
      undefined_public:
	mov	[error_info],ebx
	jmp	undefined_symbol
      elf64_public:
	cmp	dl,4
	jne	invalid_use_of_symbol
	mov	dx,[eax+6]
	jmp	section_for_public_ok
      public_absolute:
	mov	dx,0FFF1h
      section_for_public_ok:
	mov	eax,[esi+4]
	stos	dword [edi]
	test	[format_flags],8
	jnz	elf64_public_symbol
	movzx	eax,byte [ebx+9]
	shr	al,1
	and	al,1
	neg	eax
	cmp	eax,[ebx+4]
	jne	value_out_of_range
	xor	eax,[ebx]
	js	value_out_of_range
	mov	eax,[ebx]
	stos	dword [edi]
	xor	eax,eax
	mov	al,[ebx+10]
	stos	dword [edi]
	mov	eax,edx
	shl	eax,16
	mov	al,10h
	cmp	byte [ebx+10],0
	je	elf_public_function
	or	al,1
	jmp	store_elf_public_info
      elf_public_function:
	or	al,2
      store_elf_public_info:
	stos	dword [edi]
	jmp	public_symbol_ok
      elf64_public_symbol:
	mov	eax,edx
	shl	eax,16
	mov	al,10h
	cmp	byte [ebx+10],0
	je	elf64_public_function
	or	al,1
	jmp	store_elf64_public_info
      elf64_public_function:
	or	al,2
      store_elf64_public_info:
	stos	dword [edi]
	mov	al,[ebx+9]
	shl	eax,31-1
	xor	eax,[ebx+4]
	js	value_out_of_range
	mov	eax,[ebx]
	stos	dword [edi]
	mov	eax,[ebx+4]
	stos	dword [edi]
	mov	al,[ebx+10]
	stos	dword [edi]
	xor	al,al
	stos	dword [edi]
      public_symbol_ok:
	inc	ecx
	mov	eax,ecx
	shl	eax,8
	mov	al,0C0h
	mov	[esi],eax
	add	esi,10h
	jmp	find_other_symbols
      make_extrn_symbol:
	mov	eax,[esi+4]
	stos	dword [edi]
	test	[format_flags],8
	jnz	elf64_extrn_symbol
	xor	eax,eax
	stos	dword [edi]
	mov	eax,[esi+8]
	stos	dword [edi]
	mov	eax,10h
	stos	dword [edi]
	jmp	extrn_symbol_ok
      elf64_extrn_symbol:
	mov	eax,10h
	stos	dword [edi]
	xor	al,al
	stos	dword [edi]
	stos	dword [edi]
	mov	eax,[esi+8]
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
      extrn_symbol_ok:
	inc	ecx
	mov	eax,ecx
	shl	eax,8
	mov	al,80h
	mov	[esi],eax
	add	esi,0Ch
	jmp	find_other_symbols
      elf_symbol_table_ok:
	mov	edx,edi
	mov	ebx,[free_additional_memory]
	xor	al,al
	stos	byte [edi]
	add	edi,16
	mov	[edx+1],edx
	add	ebx,10h
	test	[format_flags],8
	jz	make_string_table
	add	ebx,8
      make_string_table:
	cmp	ebx,edx
	je	elf_string_table_ok
	test	[format_flags],8
	jnz	make_elf64_string
	cmp	byte [ebx+0Dh],0
	je	rel_prefix_ok
	mov	byte [ebx+0Dh],0
	mov	eax,'.rel'
	stos	dword [edi]
      rel_prefix_ok:
	mov	esi,edi
	sub	esi,edx
	xchg	esi,[ebx]
	add	ebx,10h
      make_elf_string:
	or	esi,esi
	jz	default_string
	lods	dword [esi]
	mov	ecx,eax
	rep	movs byte [edi],[esi]
	xor	al,al
	stos	byte [edi]
	jmp	make_string_table
      make_elf64_string:
	cmp	byte [ebx+5],0
	je	elf64_rel_prefix_ok
	mov	byte [ebx+5],0
	mov	eax,'.rel'
	stos	dword [edi]
	mov	al,'a'
	stos	byte [edi]
      elf64_rel_prefix_ok:
	mov	esi,edi
	sub	esi,edx
	xchg	esi,[ebx]
	add	ebx,18h
	jmp	make_elf_string
      default_string:
	mov	eax,'.fla'
	stos	dword [edi]
	mov	ax,'t'
	stos	word [edi]
	jmp	make_string_table
      elf_string_table_ok:
	mov	[edx+1+8],edi
	mov	ebx,[code_start]
	mov	eax,edi
	sub	eax,[free_additional_memory]
	test	[format_flags],8
	jnz	finish_elf64_header
	mov	[ebx+20h],eax
	mov	eax,[current_section]
	inc	ax
	jz	format_limitations_exceeded
	mov	[ebx+32h],ax
	inc	ax
	jz	format_limitations_exceeded
	mov	[ebx+30h],ax
	jmp	elf_header_finished
      finish_elf64_header:
	mov	[ebx+28h],eax
	mov	eax,[current_section]
	inc	ax
	jz	format_limitations_exceeded
	mov	[ebx+3Eh],ax
	inc	ax
	jz	format_limitations_exceeded
	mov	[ebx+3Ch],ax
      elf_header_finished:
	xor	eax,eax
	mov	ecx,10
	rep	stos dword [edi]
	test	[format_flags],8
	jz	elf_null_section_ok
	mov	ecx,6
	rep	stos dword [edi]
      elf_null_section_ok:
	mov	esi,ebp
	xor	ecx,ecx
      make_section_entry:
	mov	ebx,edi
	mov	eax,[esi+4]
	mov	eax,[eax]
	stos	dword [edi]
	mov	eax,1
	cmp	dword [esi+0Ch],0
	je	bss_section
	test	byte [esi+14h],80h
	jz	section_type_ok
      bss_section:
	mov	al,8
      section_type_ok:
	stos	dword [edi]
	mov	eax,[esi+14h]
	and	al,3Fh
	call	store_elf_machine_word
	xor	eax,eax
	call	store_elf_machine_word
	mov	eax,[esi+8]
	mov	[image_base],eax
	sub	eax,[code_start]
	call	store_elf_machine_word
	mov	eax,[esi+0Ch]
	call	store_elf_machine_word
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	mov	eax,[esi+10h]
	call	store_elf_machine_word
	xor	eax,eax
	call	store_elf_machine_word
	inc	ecx
	add	esi,20h
	xchg	edi,[esp]
	mov	ebp,edi
      convert_relocations:
	cmp	esi,[free_additional_memory]
	je	relocations_converted
	mov	al,[esi]
	or	al,al
	jz	relocations_converted
	cmp	al,80h
	jb	make_relocation_entry
	cmp	al,0C0h
	jb	relocation_entry_ok
	add	esi,10h
	jmp	convert_relocations
      make_relocation_entry:
	test	[format_flags],8
	jnz	make_elf64_relocation_entry
	mov	eax,[esi+4]
	stos	dword [edi]
	mov	eax,[esi+8]
	mov	eax,[eax]
	mov	al,[esi]
	stos	dword [edi]
	jmp	relocation_entry_ok
      make_elf64_relocation_entry:
	mov	eax,[esi+4]
	stos	dword [edi]
	xor	eax,eax
	stos	dword [edi]
	movzx	eax,byte [esi]
	stos	dword [edi]
	mov	eax,[esi+8]
	mov	eax,[eax]
	shr	eax,8
	stos	dword [edi]
	xor	eax,eax
	push	edx
	mov	edx,[esi+4]
	add	edx,[image_base]
	xchg	eax,[edx]
	stos	dword [edi]
	cmp	byte [esi],1
	je	addend_64bit
	pop	edx
	sar	eax,31
	stos	dword [edi]
	jmp	relocation_entry_ok
      addend_64bit:
	xor	eax,eax
	xchg	eax,[edx+4]
	stos	dword [edi]
	pop	edx
      relocation_entry_ok:
	add	esi,0Ch
	jmp	convert_relocations
      store_elf_machine_word:
	stos	dword [edi]
	test	[format_flags],8
	jz	elf_machine_word_ok
	and	dword [edi],0
	add	edi,4
      elf_machine_word_ok:
	ret
      relocations_converted:
	cmp	edi,ebp
	xchg	edi,[esp]
	je	rel_section_ok
	mov	eax,[ebx]
	sub	eax,4
	test	[format_flags],8
	jz	store_relocations_name_offset
	dec	eax
      store_relocations_name_offset:
	stos	dword [edi]
	test	[format_flags],8
	jnz	rela_section
	mov	eax,9
	jmp	store_relocations_type
      rela_section:
	mov	eax,4
      store_relocations_type:
	stos	dword [edi]
	xor	al,al
	call	store_elf_machine_word
	call	store_elf_machine_word
	mov	eax,ebp
	sub	eax,[code_start]
	call	store_elf_machine_word
	mov	eax,[esp]
	sub	eax,ebp
	call	store_elf_machine_word
	mov	eax,[current_section]
	stos	dword [edi]
	mov	eax,ecx
	stos	dword [edi]
	inc	ecx
	test	[format_flags],8
	jnz	finish_elf64_rela_section
	mov	eax,4
	stos	dword [edi]
	mov	al,8
	stos	dword [edi]
	jmp	rel_section_ok
      finish_elf64_rela_section:
	mov	eax,8
	stos	dword [edi]
	xor	al,al
	stos	dword [edi]
	mov	al,24
	stos	dword [edi]
	xor	al,al
	stos	dword [edi]
      rel_section_ok:
	cmp	esi,[free_additional_memory]
	jne	make_section_entry
	pop	eax
	mov	ebx,[code_start]
	sub	eax,ebx
	mov	[code_size],eax
	mov	ecx,20h
	test	[format_flags],8
	jz	adjust_elf_section_headers_offset
	mov	ecx,28h
      adjust_elf_section_headers_offset:
	add	[ebx+ecx],eax
	mov	eax,1
	stos	dword [edi]
	mov	al,2
	stos	dword [edi]
	xor	al,al
	call	store_elf_machine_word
	call	store_elf_machine_word
	mov	eax,[code_size]
	call	store_elf_machine_word
	mov	eax,[edx+1]
	sub	eax,[free_additional_memory]
	call	store_elf_machine_word
	mov	eax,[current_section]
	inc	eax
	stos	dword [edi]
	mov	eax,[number_of_sections]
	inc	eax
	stos	dword [edi]
	test	[format_flags],8
	jnz	finish_elf64_sym_section
	mov	eax,4
	stos	dword [edi]
	mov	al,10h
	stos	dword [edi]
	jmp	sym_section_ok
      finish_elf64_sym_section:
	mov	eax,8
	stos	dword [edi]
	xor	al,al
	stos	dword [edi]
	mov	al,18h
	stos	dword [edi]
	xor	al,al
	stos	dword [edi]
      sym_section_ok:
	mov	al,1+8
	stos	dword [edi]
	mov	al,3
	stos	dword [edi]
	xor	al,al
	call	store_elf_machine_word
	call	store_elf_machine_word
	mov	eax,[edx+1]
	sub	eax,[free_additional_memory]
	add	eax,[code_size]
	call	store_elf_machine_word
	mov	eax,[edx+1+8]
	sub	eax,[edx+1]
	call	store_elf_machine_word
	xor	eax,eax
	stos	dword [edi]
	stos	dword [edi]
	mov	al,1
	call	store_elf_machine_word
	xor	eax,eax
	call	store_elf_machine_word
	mov	eax,'tab'
	mov	dword [edx+1],'.sym'
	mov	[edx+1+4],eax
	mov	dword [edx+1+8],'.str'
	mov	[edx+1+8+4],eax
	mov	[resource_data],edx
	mov	[written_size],0
	mov	edx,[output_file]
	call	create
	jc	write_failed
	call	write_code
	mov	ecx,edi
	mov	edx,[free_additional_memory]
	sub	ecx,edx
	add	[written_size],ecx
	call	write
	jc	write_failed
	jmp	output_written

format_elf_exe:
	add	esi,2
	or	[format_flags],1
	cmp	byte [esi],'('
	jne	elf_exe_brand_ok
	inc	esi
	cmp	byte [esi],'.'
	je	invalid_value
	push	edx
	call	get_byte_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	pop	edx
	mov	[edx+7],al
      elf_exe_brand_ok:
	mov	[image_base],8048000h
	cmp	byte [esi],80h
	jne	elf_exe_base_ok
	lods	word [esi]
	cmp	ah,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	push	edx
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	[image_base],eax
	pop	edx
      elf_exe_base_ok:
	mov	byte [edx+10h],2
	mov	byte [edx+2Ah],20h
	mov	ebx,edi
	mov	ecx,20h shr 2
	cmp	[current_pass],0
	je	init_elf_segments
	imul	ecx,[number_of_sections]
      init_elf_segments:
	xor	eax,eax
	rep	stos dword [edi]
	and	[number_of_sections],0
	mov	byte [ebx],1
	mov	word [ebx+1Ch],1000h
	mov	byte [ebx+18h],111b
	mov	eax,edi
	xor	ebp,ebp
	xor	cl,cl
	sub	eax,[code_start]
	sbb	ebp,0
	sbb	cl,0
	mov	[ebx+4],eax
	add	eax,[image_base]
	adc	ebp,0
	adc	cl,0
	mov	[ebx+8],eax
	mov	[ebx+0Ch],eax
	mov	[edx+18h],eax
	not	eax
	not	ebp
	not	cl
	add	eax,1
	adc	ebp,0
	adc	cl,0
	add	eax,edi
	adc	ebp,0
	adc	cl,0
	mov	edx,ebp
      elf_exe_addressing_setup:
	push	eax
	call	init_addressing_space
	pop	eax
	mov	[ebx],eax
	mov	[ebx+4],edx
	mov	[ebx+8],cl
	mov	[symbols_stream],edi
	jmp	format_defined
      format_elf64_exe:
	add	esi,2
	or	[format_flags],1
	cmp	byte [esi],'('
	jne	elf64_exe_brand_ok
	inc	esi
	cmp	byte [esi],'.'
	je	invalid_value
	push	edx
	call	get_byte_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	pop	edx
	mov	[edx+7],al
      elf64_exe_brand_ok:
	mov	[image_base],400000h
	and	[image_base_high],0
	cmp	byte [esi],80h
	jne	elf64_exe_base_ok
	lods	word [esi]
	cmp	ah,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	push	edx
	call	get_qword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	[image_base],eax
	mov	[image_base_high],edx
	pop	edx
      elf64_exe_base_ok:
	mov	byte [edx+10h],2
	mov	byte [edx+36h],38h
	mov	ebx,edi
	mov	ecx,38h shr 2
	cmp	[current_pass],0
	je	init_elf64_segments
	imul	ecx,[number_of_sections]
      init_elf64_segments:
	xor	eax,eax
	rep	stos dword [edi]
	and	[number_of_sections],0
	mov	byte [ebx],1
	mov	word [ebx+30h],1000h
	mov	byte [ebx+4],111b
	push	edx
	mov	eax,edi
	sub	eax,[code_start]
	mov	[ebx+8],eax
	xor	edx,edx
	xor	cl,cl
	add	eax,[image_base]
	adc	edx,[image_base_high]
	adc	cl,0
	mov	[ebx+10h],eax
	mov	[ebx+10h+4],edx
	mov	[ebx+18h],eax
	mov	[ebx+18h+4],edx
	pop	ebx
	mov	[ebx+18h],eax
	mov	[ebx+18h+4],edx
	not	eax
	not	edx
	not	cl
	add	eax,1
	adc	edx,0
	adc	cl,0
	add	eax,edi
	adc	edx,0
	adc	cl,0
	jmp	elf_exe_addressing_setup
elf_entry:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	test	[format_flags],8
	jnz	elf64_entry
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[code_start]
	mov	[edx+18h],eax
	jmp	instruction_assembled
      elf64_entry:
	call	get_qword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	ebx,[code_start]
	mov	[ebx+18h],eax
	mov	[ebx+1Ch],edx
	jmp	instruction_assembled
elf_segment:
	bt	[format_flags],0
	jnc	illegal_instruction
	test	[format_flags],8
	jnz	elf64_segment
	call	close_elf_segment
	push	eax
	call	create_addressing_space
	mov	ebp,ebx
	mov	ebx,[number_of_sections]
	shl	ebx,5
	add	ebx,[code_start]
	add	ebx,34h
	cmp	ebx,[symbols_stream]
	jb	new_elf_segment
	mov	ebx,[symbols_stream]
	sub	ebx,20h
	push	edi
	mov	edi,ebx
	mov	ecx,20h shr 2
	xor	eax,eax
	rep	stos dword [edi]
	pop	edi
	or	[next_pass_needed],-1
      new_elf_segment:
	mov	byte [ebx],1
	mov	word [ebx+1Ch],1000h
      elf_segment_flags:
	cmp	byte [esi],1Eh
	je	elf_segment_type
	cmp	byte [esi],19h
	jne	elf_segment_flags_ok
	lods	word [esi]
	sub	ah,28
	jbe	invalid_argument
	cmp	ah,1
	je	mark_elf_segment_flag
	cmp	ah,3
	ja	invalid_argument
	xor	ah,1
	cmp	ah,2
	je	mark_elf_segment_flag
	inc	ah
      mark_elf_segment_flag:
	test	[ebx+18h],ah
	jnz	setting_already_specified
	or	[ebx+18h],ah
	jmp	elf_segment_flags
      elf_segment_type:
	cmp	byte [ebx],1
	jne	setting_already_specified
	lods	word [esi]
	mov	ecx,[number_of_sections]
	jecxz	elf_segment_type_ok
	mov	edx,[code_start]
	add	edx,34h
      scan_elf_segment_types:
	cmp	edx,[symbols_stream]
	jae	elf_segment_type_ok
	cmp	[edx],ah
	je	data_already_defined
	add	edx,20h
	loop	scan_elf_segment_types
      elf_segment_type_ok:
	mov	[ebx],ah
	mov	word [ebx+1Ch],1
	jmp	elf_segment_flags
      elf_segment_flags_ok:
	mov	eax,edi
	sub	eax,[code_start]
	mov	[ebx+4],eax
	pop	edx
	and	eax,0FFFh
	add	edx,eax
	mov	[ebx+8],edx
	mov	[ebx+0Ch],edx
	mov	eax,edx
	xor	edx,edx
	xor	cl,cl
	not	eax
	not	edx
	not	cl
	add	eax,1
	adc	edx,0
	adc	cl,0
	add	eax,edi
	adc	edx,0
	adc	cl,0
      elf_segment_addressing_setup:
	mov	[ds:ebp],eax
	mov	[ds:ebp+4],edx
	mov	[ds:ebp+8],cl
	inc	[number_of_sections]
	jmp	instruction_assembled
      close_elf_segment:
	cmp	[number_of_sections],0
	jne	finish_elf_segment
	cmp	edi,[symbols_stream]
	jne	first_elf_segment_ok
	push	edi
	mov	edi,[code_start]
	add	edi,34h
	mov	ecx,20h shr 2
	xor	eax,eax
	rep	stos dword [edi]
	pop	edi
	mov	eax,[image_base]
	ret
      first_elf_segment_ok:
	inc	[number_of_sections]
      finish_elf_segment:
	mov	ebx,[number_of_sections]
	dec	ebx
	shl	ebx,5
	add	ebx,[code_start]
	add	ebx,34h
	mov	eax,edi
	sub	eax,[code_start]
	sub	eax,[ebx+4]
	mov	edx,edi
	cmp	edi,[undefined_data_end]
	jne	elf_segment_size_ok
	mov	edi,[undefined_data_start]
      elf_segment_size_ok:
	mov	[ebx+14h],eax
	add	eax,edi
	sub	eax,edx
	mov	[ebx+10h],eax
	and	[undefined_data_end],0
	mov	eax,[ebx+8]
	cmp	byte [ebx],1
	jne	elf_segment_position_ok
	add	eax,[ebx+14h]
	add	eax,0FFFh
      elf_segment_position_ok:
	and	eax,not 0FFFh
	ret
      elf64_segment:
	call	close_elf64_segment
	push	eax edx
	call	create_addressing_space
	mov	ebp,ebx
	mov	ebx,[number_of_sections]
	imul	ebx,38h
	add	ebx,[code_start]
	add	ebx,40h
	cmp	ebx,[symbols_stream]
	jb	new_elf64_segment
	mov	ebx,[symbols_stream]
	sub	ebx,38h
	push	edi
	mov	edi,ebx
	mov	ecx,38h shr 2
	xor	eax,eax
	rep	stos dword [edi]
	pop	edi
	or	[next_pass_needed],-1
      new_elf64_segment:
	mov	byte [ebx],1
	mov	word [ebx+30h],1000h
      elf64_segment_flags:
	cmp	byte [esi],1Eh
	je	elf64_segment_type
	cmp	byte [esi],19h
	jne	elf64_segment_flags_ok
	lods	word [esi]
	sub	ah,28
	jbe	invalid_argument
	cmp	ah,1
	je	mark_elf64_segment_flag
	cmp	ah,3
	ja	invalid_argument
	xor	ah,1
	cmp	ah,2
	je	mark_elf64_segment_flag
	inc	ah
      mark_elf64_segment_flag:
	test	[ebx+4],ah
	jnz	setting_already_specified
	or	[ebx+4],ah
	jmp	elf64_segment_flags
      elf64_segment_type:
	cmp	byte [ebx],1
	jne	setting_already_specified
	lods	word [esi]
	mov	ecx,[number_of_sections]
	jecxz	elf64_segment_type_ok
	mov	edx,[code_start]
	add	edx,40h
      scan_elf64_segment_types:
	cmp	edx,[symbols_stream]
	jae	elf64_segment_type_ok
	cmp	[edx],ah
	je	data_already_defined
	add	edx,38h
	loop	scan_elf64_segment_types
      elf64_segment_type_ok:
	mov	[ebx],ah
	mov	word [ebx+30h],1
	jmp	elf64_segment_flags
      elf64_segment_flags_ok:
	mov	ecx,edi
	sub	ecx,[code_start]
	mov	[ebx+8],ecx
	pop	edx eax
	and	ecx,0FFFh
	add	eax,ecx
	adc	edx,0
	mov	[ebx+10h],eax
	mov	[ebx+10h+4],edx
	mov	[ebx+18h],eax
	mov	[ebx+18h+4],edx
	xor	cl,cl
	not	eax
	not	edx
	not	cl
	add	eax,1
	adc	edx,0
	adc	cl,0
	add	eax,edi
	adc	edx,0
	adc	cl,0
	jmp	elf_segment_addressing_setup
      close_elf64_segment:
	cmp	[number_of_sections],0
	jne	finish_elf64_segment
	cmp	edi,[symbols_stream]
	jne	first_elf64_segment_ok
	push	edi
	mov	edi,[code_start]
	add	edi,40h
	mov	ecx,38h shr 2
	xor	eax,eax
	rep	stos dword [edi]
	pop	edi
	mov	eax,[image_base]
	mov	edx,[image_base_high]
	ret
      first_elf64_segment_ok:
	inc	[number_of_sections]
      finish_elf64_segment:
	mov	ebx,[number_of_sections]
	dec	ebx
	imul	ebx,38h
	add	ebx,[code_start]
	add	ebx,40h
	mov	eax,edi
	sub	eax,[code_start]
	sub	eax,[ebx+8]
	mov	edx,edi
	cmp	edi,[undefined_data_end]
	jne	elf64_segment_size_ok
	mov	edi,[undefined_data_start]
      elf64_segment_size_ok:
	mov	[ebx+28h],eax
	add	eax,edi
	sub	eax,edx
	mov	[ebx+20h],eax
	and	[undefined_data_end],0
	mov	eax,[ebx+10h]
	mov	edx,[ebx+10h+4]
	cmp	byte [ebx],1
	jne	elf64_segment_position_ok
	add	eax,[ebx+28h]
	adc	edx,0
	add	eax,0FFFh
	adc	edx,0
      elf64_segment_position_ok:
	and	eax,not 0FFFh
	ret
close_elf_exe:
	test	[format_flags],8
	jnz	close_elf64_exe
	call	close_elf_segment
	mov	edx,[code_start]
	mov	eax,[number_of_sections]
	mov	byte [edx+1Ch],34h
	mov	[edx+2Ch],ax
	shl	eax,5
	add	eax,edx
	add	eax,34h
	cmp	eax,[symbols_stream]
	je	elf_exe_ok
	or	[next_pass_needed],-1
      elf_exe_ok:
	ret
      close_elf64_exe:
	call	close_elf64_segment
	mov	edx,[code_start]
	mov	eax,[number_of_sections]
	mov	byte [edx+20h],40h
	mov	[edx+38h],ax
	imul	eax,38h
	add	eax,edx
	add	eax,40h
	cmp	eax,[symbols_stream]
	je	elf64_exe_ok
	or	[next_pass_needed],-1
      elf64_exe_ok:
	ret

# x86_64 instructions

simple_instruction_except64:
	cmp	[code_type],64
	je	illegal_instruction
simple_instruction:
	stos	byte [edi]
	jmp	instruction_assembled
simple_instruction_only64:
	cmp	[code_type],64
	jne	illegal_instruction
	jmp	simple_instruction
simple_instruction_16bit_except64:
	cmp	[code_type],64
	je	illegal_instruction
simple_instruction_16bit:
	cmp	[code_type],16
	jne	size_prefix
	stos	byte [edi]
	jmp	instruction_assembled
      size_prefix:
	mov	ah,al
	mov	al,66h
	stos	word [edi]
	jmp	instruction_assembled
simple_instruction_32bit_except64:
	cmp	[code_type],64
	je	illegal_instruction
simple_instruction_32bit:
	cmp	[code_type],16
	je	size_prefix
	stos	byte [edi]
	jmp	instruction_assembled
iret_instruction:
	cmp	[code_type],64
	jne	simple_instruction
simple_instruction_64bit:
	cmp	[code_type],64
	jne	illegal_instruction
	mov	ah,al
	mov	al,48h
	stos	word [edi]
	jmp	instruction_assembled
simple_extended_instruction_64bit:
	cmp	[code_type],64
	jne	illegal_instruction
	mov	byte [edi],48h
	inc	edi
simple_extended_instruction:
	mov	ah,al
	mov	al,0Fh
	stos	word [edi]
	jmp	instruction_assembled
prefix_instruction:
	stos	byte [edi]
	or	[prefix_flags],1
	jmp	continue_line
segment_prefix:
	mov	ah,al
	shr	ah,4
	cmp	ah,3
	jne	illegal_instruction
	and	al,1111b
	mov	[segment_register],al
	call	store_segment_prefix
	or	[prefix_flags],1
	jmp	continue_line
bnd_prefix_instruction:
	stos	byte [edi]
	or	[prefix_flags],1 + 10h
	jmp	continue_line
int_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	ah,1
	ja	invalid_operand_size
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	test	eax,eax
	jns	int_imm_ok
	call	recoverable_overflow
      int_imm_ok:
	mov	ah,al
	mov	al,0CDh
	stos	word [edi]
	jmp	instruction_assembled
aa_instruction:
	cmp	[code_type],64
	je	illegal_instruction
	push	eax
	mov	bl,10
	cmp	byte [esi],'('
	jne	aa_store
	inc	esi
	xor	al,al
	xchg	al,[operand_size]
	cmp	al,1
	ja	invalid_operand_size
	call	get_byte_value
	mov	bl,al
      aa_store:
	cmp	[operand_size],0
	jne	invalid_operand
	pop	eax
	mov	ah,bl
	stos	word [edi]
	jmp	instruction_assembled

basic_instruction:
	mov	[base_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	basic_reg
	cmp	al,'['
	jne	invalid_operand
      basic_mem:
	call	get_address
	push	edx ebx ecx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	basic_mem_imm
	cmp	al,10h
	jne	invalid_operand
      basic_mem_reg:
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	pop	ecx ebx edx
	mov	al,ah
	cmp	al,1
	je	instruction_ready
	call	operand_autodetect
	inc	[base_code]
      instruction_ready:
	call	store_instruction
	jmp	instruction_assembled
      basic_mem_imm:
	mov	al,[operand_size]
	cmp	al,1
	jb	basic_mem_imm_nosize
	je	basic_mem_imm_8bit
	cmp	al,2
	je	basic_mem_imm_16bit
	cmp	al,4
	je	basic_mem_imm_32bit
	cmp	al,8
	jne	invalid_operand_size
      basic_mem_imm_64bit:
	cmp	[size_declared],0
	jne	long_immediate_not_encodable
	call	operand_64bit
	call	get_simm32
	cmp	[value_type],4
	jae	long_immediate_not_encodable
	jmp	basic_mem_imm_32bit_ok
      basic_mem_imm_nosize:
	call	recoverable_unknown_size
      basic_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	al,[base_code]
	shr	al,3
	mov	[postbyte_register],al
	pop	ecx ebx edx
	mov	[base_code],80h
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      basic_mem_imm_16bit:
	call	operand_16bit
	call	get_word_value
	mov	word [value],ax
	mov	al,[base_code]
	shr	al,3
	mov	[postbyte_register],al
	pop	ecx ebx edx
	cmp	[value_type],0
	jne	basic_mem_imm_16bit_store
	cmp	[size_declared],0
	jne	basic_mem_imm_16bit_store
	cmp	word [value],80h
	jb	basic_mem_simm_8bit
	cmp	word [value],-80h
	jae	basic_mem_simm_8bit
      basic_mem_imm_16bit_store:
	mov	[base_code],81h
	call	store_instruction_with_imm16
	jmp	instruction_assembled
      basic_mem_simm_8bit:
	mov	[base_code],83h
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      basic_mem_imm_32bit:
	call	operand_32bit
	call	get_dword_value
      basic_mem_imm_32bit_ok:
	mov	dword [value],eax
	mov	al,[base_code]
	shr	al,3
	mov	[postbyte_register],al
	pop	ecx ebx edx
	cmp	[value_type],0
	jne	basic_mem_imm_32bit_store
	cmp	[size_declared],0
	jne	basic_mem_imm_32bit_store
	cmp	dword [value],80h
	jb	basic_mem_simm_8bit
	cmp	dword [value],-80h
	jae	basic_mem_simm_8bit
      basic_mem_imm_32bit_store:
	mov	[base_code],81h
	call	store_instruction_with_imm32
	jmp	instruction_assembled
      get_simm32:
	call	get_qword_value
	mov	ecx,edx
	cdq
	cmp	ecx,edx
	jne	value_out_of_range
	cmp	[value_type],4
	jne	get_simm32_ok
	mov	[value_type],2
      get_simm32_ok:
	ret
      basic_reg:
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	basic_reg_reg
	cmp	al,'('
	je	basic_reg_imm
	cmp	al,'['
	jne	invalid_operand
      basic_reg_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	basic_reg_mem_8bit
	call	operand_autodetect
	add	[base_code],3
	jmp	instruction_ready
      basic_reg_mem_8bit:
	add	[base_code],2
	jmp	instruction_ready
      basic_reg_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,[postbyte_register]
	mov	[postbyte_register],al
	mov	al,ah
	cmp	al,1
	je	nomem_instruction_ready
	call	operand_autodetect
	inc	[base_code]
      nomem_instruction_ready:
	call	store_nomem_instruction
	jmp	instruction_assembled
      basic_reg_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	basic_reg_imm_8bit
	cmp	al,2
	je	basic_reg_imm_16bit
	cmp	al,4
	je	basic_reg_imm_32bit
	cmp	al,8
	jne	invalid_operand_size
      basic_reg_imm_64bit:
	cmp	[size_declared],0
	jne	long_immediate_not_encodable
	call	operand_64bit
	call	get_simm32
	cmp	[value_type],4
	jae	long_immediate_not_encodable
	jmp	basic_reg_imm_32bit_ok
      basic_reg_imm_8bit:
	call	get_byte_value
	mov	dl,al
	mov	bl,[base_code]
	shr	bl,3
	xchg	bl,[postbyte_register]
	or	bl,bl
	jz	basic_al_imm
	mov	[base_code],80h
	call	store_nomem_instruction
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      basic_al_imm:
	mov	al,[base_code]
	add	al,4
	stos	byte [edi]
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      basic_reg_imm_16bit:
	call	operand_16bit
	call	get_word_value
	mov	dx,ax
	mov	bl,[base_code]
	shr	bl,3
	xchg	bl,[postbyte_register]
	cmp	[value_type],0
	jne	basic_reg_imm_16bit_store
	cmp	[size_declared],0
	jne	basic_reg_imm_16bit_store
	cmp	dx,80h
	jb	basic_reg_simm_8bit
	cmp	dx,-80h
	jae	basic_reg_simm_8bit
      basic_reg_imm_16bit_store:
	or	bl,bl
	jz	basic_ax_imm
	mov	[base_code],81h
	call	store_nomem_instruction
      basic_store_imm_16bit:
	mov	ax,dx
	call	mark_relocation
	stos	word [edi]
	jmp	instruction_assembled
      basic_reg_simm_8bit:
	mov	[base_code],83h
	call	store_nomem_instruction
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      basic_ax_imm:
	add	[base_code],5
	call	store_classic_instruction_code
	jmp	basic_store_imm_16bit
      basic_reg_imm_32bit:
	call	operand_32bit
	call	get_dword_value
      basic_reg_imm_32bit_ok:
	mov	edx,eax
	mov	bl,[base_code]
	shr	bl,3
	xchg	bl,[postbyte_register]
	cmp	[value_type],0
	jne	basic_reg_imm_32bit_store
	cmp	[size_declared],0
	jne	basic_reg_imm_32bit_store
	cmp	edx,80h
	jb	basic_reg_simm_8bit
	cmp	edx,-80h
	jae	basic_reg_simm_8bit
      basic_reg_imm_32bit_store:
	or	bl,bl
	jz	basic_eax_imm
	mov	[base_code],81h
	call	store_nomem_instruction
      basic_store_imm_32bit:
	mov	eax,edx
	call	mark_relocation
	stos	dword [edi]
	jmp	instruction_assembled
      basic_eax_imm:
	add	[base_code],5
	call	store_classic_instruction_code
	jmp	basic_store_imm_32bit
      recoverable_unknown_size:
	cmp	[error_line],0
	jne	ignore_unknown_size
	push	[current_line]
	pop	[error_line]
	mov	[error],operand_size_not_specified
      ignore_unknown_size:
	ret
single_operand_instruction:
	mov	[base_code],0F6h
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	single_reg
	cmp	al,'['
	jne	invalid_operand
      single_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	single_mem_8bit
	jb	single_mem_nosize
	call	operand_autodetect
	inc	[base_code]
	jmp	instruction_ready
      single_mem_nosize:
	call	recoverable_unknown_size
      single_mem_8bit:
	jmp	instruction_ready
      single_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,ah
	cmp	al,1
	je	single_reg_8bit
	call	operand_autodetect
	inc	[base_code]
      single_reg_8bit:
	jmp	nomem_instruction_ready
mov_instruction:
	mov	[base_code],88h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	mov_reg
	cmp	al,14h
	je	mov_creg
	cmp	al,'['
	jne	invalid_operand
      mov_mem:
	call	get_address
	push	edx ebx ecx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	mov_mem_imm
	cmp	al,10h
	jne	invalid_operand
      mov_mem_reg:
	lods	byte [esi]
	cmp	al,30h
	jb	mov_mem_general_reg
	cmp	al,40h
	jb	mov_mem_sreg
      mov_mem_general_reg:
	call	convert_register
	mov	[postbyte_register],al
	pop	ecx ebx edx
	cmp	ah,1
	je	mov_mem_reg_8bit
	mov	al,ah
	call	operand_autodetect
	mov	al,[postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_mem_ax
	inc	[base_code]
	jmp	instruction_ready
      mov_mem_reg_8bit:
	or	al,bl
	or	al,bh
	jnz	instruction_ready
      mov_mem_al:
	test	ch,22h
	jnz	mov_mem_address16_al
	test	ch,44h
	jnz	mov_mem_address32_al
	test	ch,88h
	jnz	mov_mem_address64_al
	or	ch,ch
	jnz	invalid_address_size
	cmp	[code_type],64
	je	mov_mem_address64_al
	cmp	[code_type],32
	je	mov_mem_address32_al
	cmp	edx,10000h
	jb	mov_mem_address16_al
      mov_mem_address32_al:
	call	store_segment_prefix_if_necessary
	call	address_32bit_prefix
	mov	[base_code],0A2h
      store_mov_address32:
	call	store_classic_instruction_code
	call	store_address_32bit_value
	jmp	instruction_assembled
      mov_mem_address16_al:
	call	store_segment_prefix_if_necessary
	call	address_16bit_prefix
	mov	[base_code],0A2h
      store_mov_address16:
	cmp	[code_type],64
	je	invalid_address
	call	store_classic_instruction_code
	mov	eax,edx
	stos	word [edi]
	cmp	edx,10000h
	jge	value_out_of_range
	jmp	instruction_assembled
      mov_mem_address64_al:
	call	store_segment_prefix_if_necessary
	mov	[base_code],0A2h
      store_mov_address64:
	call	store_classic_instruction_code
	call	store_address_64bit_value
	jmp	instruction_assembled
      mov_mem_ax:
	test	ch,22h
	jnz	mov_mem_address16_ax
	test	ch,44h
	jnz	mov_mem_address32_ax
	test	ch,88h
	jnz	mov_mem_address64_ax
	or	ch,ch
	jnz	invalid_address_size
	cmp	[code_type],64
	je	mov_mem_address64_ax
	cmp	[code_type],32
	je	mov_mem_address32_ax
	cmp	edx,10000h
	jb	mov_mem_address16_ax
      mov_mem_address32_ax:
	call	store_segment_prefix_if_necessary
	call	address_32bit_prefix
	mov	[base_code],0A3h
	jmp	store_mov_address32
      mov_mem_address16_ax:
	call	store_segment_prefix_if_necessary
	call	address_16bit_prefix
	mov	[base_code],0A3h
	jmp	store_mov_address16
      mov_mem_address64_ax:
	call	store_segment_prefix_if_necessary
	mov	[base_code],0A3h
	jmp	store_mov_address64
      mov_mem_sreg:
	sub	al,31h
	mov	[postbyte_register],al
	pop	ecx ebx edx
	mov	ah,[operand_size]
	or	ah,ah
	jz	mov_mem_sreg_store
	cmp	ah,2
	jne	invalid_operand_size
      mov_mem_sreg_store:
	mov	[base_code],8Ch
	jmp	instruction_ready
      mov_mem_imm:
	mov	al,[operand_size]
	cmp	al,1
	jb	mov_mem_imm_nosize
	je	mov_mem_imm_8bit
	cmp	al,2
	je	mov_mem_imm_16bit
	cmp	al,4
	je	mov_mem_imm_32bit
	cmp	al,8
	jne	invalid_operand_size
      mov_mem_imm_64bit:
	cmp	[size_declared],0
	jne	long_immediate_not_encodable
	call	operand_64bit
	call	get_simm32
	cmp	[value_type],4
	jae	long_immediate_not_encodable
	jmp	mov_mem_imm_32bit_store
      mov_mem_imm_nosize:
	call	recoverable_unknown_size
      mov_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	[postbyte_register],0
	mov	[base_code],0C6h
	pop	ecx ebx edx
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      mov_mem_imm_16bit:
	call	operand_16bit
	call	get_word_value
	mov	word [value],ax
	mov	[postbyte_register],0
	mov	[base_code],0C7h
	pop	ecx ebx edx
	call	store_instruction_with_imm16
	jmp	instruction_assembled
      mov_mem_imm_32bit:
	call	operand_32bit
	call	get_dword_value
      mov_mem_imm_32bit_store:
	mov	dword [value],eax
	mov	[postbyte_register],0
	mov	[base_code],0C7h
	pop	ecx ebx edx
	call	store_instruction_with_imm32
	jmp	instruction_assembled
      mov_reg:
	lods	byte [esi]
	mov	ah,al
	sub	ah,10h
	and	ah,al
	test	ah,0F0h
	jnz	mov_sreg
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	mov_reg_mem
	cmp	al,'('
	je	mov_reg_imm
	cmp	al,14h
	je	mov_reg_creg
	cmp	al,10h
	jne	invalid_operand
      mov_reg_reg:
	lods	byte [esi]
	mov	ah,al
	sub	ah,10h
	and	ah,al
	test	ah,0F0h
	jnz	mov_reg_sreg
	call	convert_register
	mov	bl,[postbyte_register]
	mov	[postbyte_register],al
	mov	al,ah
	cmp	al,1
	je	mov_reg_reg_8bit
	call	operand_autodetect
	inc	[base_code]
      mov_reg_reg_8bit:
	jmp	nomem_instruction_ready
      mov_reg_sreg:
	mov	bl,[postbyte_register]
	mov	ah,al
	and	al,1111b
	mov	[postbyte_register],al
	shr	ah,4
	cmp	ah,3
	jne	invalid_operand
	dec	[postbyte_register]
	cmp	[operand_size],8
	je	mov_reg_sreg64
	cmp	[operand_size],4
	je	mov_reg_sreg32
	cmp	[operand_size],2
	jne	invalid_operand_size
	call	operand_16bit
	jmp	mov_reg_sreg_store
      mov_reg_sreg64:
	call	operand_64bit
	jmp	mov_reg_sreg_store
      mov_reg_sreg32:
	call	operand_32bit
      mov_reg_sreg_store:
	mov	[base_code],8Ch
	jmp	nomem_instruction_ready
      mov_reg_creg:
	lods	byte [esi]
	mov	bl,al
	shr	al,4
	cmp	al,4
	ja	invalid_operand
	add	al,20h
	mov	[extended_code],al
	and	bl,1111b
	xchg	bl,[postbyte_register]
	mov	[base_code],0Fh
	cmp	[code_type],64
	je	mov_reg_creg_64bit
	cmp	[operand_size],4
	jne	invalid_operand_size
	cmp	[postbyte_register],8
	jb	mov_reg_creg_store
	cmp	[extended_code],20h
	jne	mov_reg_creg_store
	mov	al,0F0h
	stos	byte [edi]
	mov	[postbyte_register],0
      mov_reg_creg_store:
	jmp	nomem_instruction_ready
      mov_reg_creg_64bit:
	cmp	[operand_size],8
	jne	invalid_operand_size
	jmp	nomem_instruction_ready
      mov_reg_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	mov_reg_mem_8bit
	call	operand_autodetect
	mov	al,[postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_ax_mem
	add	[base_code],3
	jmp	instruction_ready
      mov_reg_mem_8bit:
	mov	al,[postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_al_mem
	add	[base_code],2
	jmp	instruction_ready
      mov_al_mem:
	test	ch,22h
	jnz	mov_al_mem_address16
	test	ch,44h
	jnz	mov_al_mem_address32
	test	ch,88h
	jnz	mov_al_mem_address64
	or	ch,ch
	jnz	invalid_address_size
	cmp	[code_type],64
	je	mov_al_mem_address64
	cmp	[code_type],32
	je	mov_al_mem_address32
	cmp	edx,10000h
	jb	mov_al_mem_address16
      mov_al_mem_address32:
	call	store_segment_prefix_if_necessary
	call	address_32bit_prefix
	mov	[base_code],0A0h
	jmp	store_mov_address32
      mov_al_mem_address16:
	call	store_segment_prefix_if_necessary
	call	address_16bit_prefix
	mov	[base_code],0A0h
	jmp	store_mov_address16
      mov_al_mem_address64:
	call	store_segment_prefix_if_necessary
	mov	[base_code],0A0h
	jmp	store_mov_address64
      mov_ax_mem:
	test	ch,22h
	jnz	mov_ax_mem_address16
	test	ch,44h
	jnz	mov_ax_mem_address32
	test	ch,88h
	jnz	mov_ax_mem_address64
	or	ch,ch
	jnz	invalid_address_size
	cmp	[code_type],64
	je	mov_ax_mem_address64
	cmp	[code_type],32
	je	mov_ax_mem_address32
	cmp	edx,10000h
	jb	mov_ax_mem_address16
      mov_ax_mem_address32:
	call	store_segment_prefix_if_necessary
	call	address_32bit_prefix
	mov	[base_code],0A1h
	jmp	store_mov_address32
      mov_ax_mem_address16:
	call	store_segment_prefix_if_necessary
	call	address_16bit_prefix
	mov	[base_code],0A1h
	jmp	store_mov_address16
      mov_ax_mem_address64:
	call	store_segment_prefix_if_necessary
	mov	[base_code],0A1h
	jmp	store_mov_address64
      mov_reg_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	mov_reg_imm_8bit
	cmp	al,2
	je	mov_reg_imm_16bit
	cmp	al,4
	je	mov_reg_imm_32bit
	cmp	al,8
	jne	invalid_operand_size
      mov_reg_imm_64bit:
	call	operand_64bit
	call	get_qword_value
	mov	ecx,edx
	cmp	[size_declared],0
	jne	mov_reg_imm_64bit_store
	cmp	[value_type],4
	jae	mov_reg_imm_64bit_store
	cdq
	cmp	ecx,edx
	je	mov_reg_64bit_imm_32bit
      mov_reg_imm_64bit_store:
	push	eax ecx
	mov	al,0B8h
	call	store_mov_reg_imm_code
	pop	edx eax
	call	mark_relocation
	stos	dword [edi]
	mov	eax,edx
	stos	dword [edi]
	jmp	instruction_assembled
      mov_reg_imm_8bit:
	call	get_byte_value
	mov	dl,al
	mov	al,0B0h
	call	store_mov_reg_imm_code
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      mov_reg_imm_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit
	mov	al,0B8h
	call	store_mov_reg_imm_code
	mov	ax,dx
	call	mark_relocation
	stos	word [edi]
	jmp	instruction_assembled
      mov_reg_imm_32bit:
	call	operand_32bit
	call	get_dword_value
	mov	edx,eax
	mov	al,0B8h
	call	store_mov_reg_imm_code
      mov_store_imm_32bit:
	mov	eax,edx
	call	mark_relocation
	stos	dword [edi]
	jmp	instruction_assembled
      store_mov_reg_imm_code:
	mov	ah,[postbyte_register]
	test	ah,1000b
	jz	mov_reg_imm_prefix_ok
	or	[rex_prefix],41h
      mov_reg_imm_prefix_ok:
	and	ah,111b
	add	al,ah
	mov	[base_code],al
	call	store_classic_instruction_code
	ret
      mov_reg_64bit_imm_32bit:
	mov	edx,eax
	mov	bl,[postbyte_register]
	mov	[postbyte_register],0
	mov	[base_code],0C7h
	call	store_nomem_instruction
	jmp	mov_store_imm_32bit
      mov_sreg:
	mov	ah,al
	and	al,1111b
	mov	[postbyte_register],al
	shr	ah,4
	cmp	ah,3
	jne	invalid_operand
	cmp	al,2
	je	illegal_instruction
	dec	[postbyte_register]
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	mov_sreg_mem
	cmp	al,10h
	jne	invalid_operand
      mov_sreg_reg:
	lods	byte [esi]
	call	convert_register
	or	ah,ah
	jz	mov_sreg_reg_size_ok
	cmp	ah,2
	jne	invalid_operand_size
	mov	bl,al
      mov_sreg_reg_size_ok:
	mov	[base_code],8Eh
	jmp	nomem_instruction_ready
      mov_sreg_mem:
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	mov_sreg_mem_size_ok
	cmp	al,2
	jne	invalid_operand_size
      mov_sreg_mem_size_ok:
	mov	[base_code],8Eh
	jmp	instruction_ready
      mov_creg:
	lods	byte [esi]
	mov	ah,al
	shr	ah,4
	cmp	ah,4
	ja	invalid_operand
	add	ah,22h
	mov	[extended_code],ah
	and	al,1111b
	mov	[postbyte_register],al
	mov	[base_code],0Fh
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	bl,al
	cmp	[code_type],64
	je	mov_creg_64bit
	cmp	ah,4
	jne	invalid_operand_size
	cmp	[postbyte_register],8
	jb	mov_creg_store
	cmp	[extended_code],22h
	jne	mov_creg_store
	mov	al,0F0h
	stos	byte [edi]
	mov	[postbyte_register],0
      mov_creg_store:
	jmp	nomem_instruction_ready
      mov_creg_64bit:
	cmp	ah,8
	je	mov_creg_store
	jmp	invalid_operand_size
test_instruction:
	mov	[base_code],84h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	test_reg
	cmp	al,'['
	jne	invalid_operand
      test_mem:
	call	get_address
	push	edx ebx ecx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	test_mem_imm
	cmp	al,10h
	jne	invalid_operand
      test_mem_reg:
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	pop	ecx ebx edx
	mov	al,ah
	cmp	al,1
	je	test_mem_reg_8bit
	call	operand_autodetect
	inc	[base_code]
      test_mem_reg_8bit:
	jmp	instruction_ready
      test_mem_imm:
	mov	al,[operand_size]
	cmp	al,1
	jb	test_mem_imm_nosize
	je	test_mem_imm_8bit
	cmp	al,2
	je	test_mem_imm_16bit
	cmp	al,4
	je	test_mem_imm_32bit
	cmp	al,8
	jne	invalid_operand_size
      test_mem_imm_64bit:
	cmp	[size_declared],0
	jne	long_immediate_not_encodable
	call	operand_64bit
	call	get_simm32
	cmp	[value_type],4
	jae	long_immediate_not_encodable
	jmp	test_mem_imm_32bit_store
      test_mem_imm_nosize:
	call	recoverable_unknown_size
      test_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	[postbyte_register],0
	mov	[base_code],0F6h
	pop	ecx ebx edx
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      test_mem_imm_16bit:
	call	operand_16bit
	call	get_word_value
	mov	word [value],ax
	mov	[postbyte_register],0
	mov	[base_code],0F7h
	pop	ecx ebx edx
	call	store_instruction_with_imm16
	jmp	instruction_assembled
      test_mem_imm_32bit:
	call	operand_32bit
	call	get_dword_value
      test_mem_imm_32bit_store:
	mov	dword [value],eax
	mov	[postbyte_register],0
	mov	[base_code],0F7h
	pop	ecx ebx edx
	call	store_instruction_with_imm32
	jmp	instruction_assembled
      test_reg:
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	test_reg_mem
	cmp	al,'('
	je	test_reg_imm
	cmp	al,10h
	jne	invalid_operand
      test_reg_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,[postbyte_register]
	mov	[postbyte_register],al
	mov	al,ah
	cmp	al,1
	je	test_reg_reg_8bit
	call	operand_autodetect
	inc	[base_code]
      test_reg_reg_8bit:
	jmp	nomem_instruction_ready
      test_reg_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	test_reg_imm_8bit
	cmp	al,2
	je	test_reg_imm_16bit
	cmp	al,4
	je	test_reg_imm_32bit
	cmp	al,8
	jne	invalid_operand_size
      test_reg_imm_64bit:
	cmp	[size_declared],0
	jne	long_immediate_not_encodable
	call	operand_64bit
	call	get_simm32
	cmp	[value_type],4
	jae	long_immediate_not_encodable
	jmp	test_reg_imm_32bit_store
      test_reg_imm_8bit:
	call	get_byte_value
	mov	dl,al
	mov	bl,[postbyte_register]
	mov	[postbyte_register],0
	mov	[base_code],0F6h
	or	bl,bl
	jz	test_al_imm
	call	store_nomem_instruction
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      test_al_imm:
	mov	[base_code],0A8h
	call	store_classic_instruction_code
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      test_reg_imm_16bit:
	call	operand_16bit
	call	get_word_value
	mov	dx,ax
	mov	bl,[postbyte_register]
	mov	[postbyte_register],0
	mov	[base_code],0F7h
	or	bl,bl
	jz	test_ax_imm
	call	store_nomem_instruction
	mov	ax,dx
	call	mark_relocation
	stos	word [edi]
	jmp	instruction_assembled
      test_ax_imm:
	mov	[base_code],0A9h
	call	store_classic_instruction_code
	mov	ax,dx
	stos	word [edi]
	jmp	instruction_assembled
      test_reg_imm_32bit:
	call	operand_32bit
	call	get_dword_value
      test_reg_imm_32bit_store:
	mov	edx,eax
	mov	bl,[postbyte_register]
	mov	[postbyte_register],0
	mov	[base_code],0F7h
	or	bl,bl
	jz	test_eax_imm
	call	store_nomem_instruction
	mov	eax,edx
	call	mark_relocation
	stos	dword [edi]
	jmp	instruction_assembled
      test_eax_imm:
	mov	[base_code],0A9h
	call	store_classic_instruction_code
	mov	eax,edx
	stos	dword [edi]
	jmp	instruction_assembled
      test_reg_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	test_reg_mem_8bit
	call	operand_autodetect
	inc	[base_code]
      test_reg_mem_8bit:
	jmp	instruction_ready
xchg_instruction:
	mov	[base_code],86h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	xchg_reg
	cmp	al,'['
	jne	invalid_operand
      xchg_mem:
	call	get_address
	push	edx ebx ecx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	test_mem_reg
	jmp	invalid_operand
      xchg_reg:
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	test_reg_mem
	cmp	al,10h
	jne	invalid_operand
      xchg_reg_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,ah
	cmp	al,1
	je	xchg_reg_reg_8bit
	call	operand_autodetect
	cmp	[postbyte_register],0
	je	xchg_ax_reg
	or	bl,bl
	jnz	xchg_reg_reg_store
	mov	bl,[postbyte_register]
      xchg_ax_reg:
	cmp	[code_type],64
	jne	xchg_ax_reg_ok
	cmp	ah,4
	jne	xchg_ax_reg_ok
	or	bl,bl
	jz	xchg_reg_reg_store
      xchg_ax_reg_ok:
	test	bl,1000b
	jz	xchg_ax_reg_store
	or	[rex_prefix],41h
	and	bl,111b
      xchg_ax_reg_store:
	add	bl,90h
	mov	[base_code],bl
	call	store_classic_instruction_code
	jmp	instruction_assembled
      xchg_reg_reg_store:
	inc	[base_code]
      xchg_reg_reg_8bit:
	jmp	nomem_instruction_ready
push_instruction:
	mov	[push_size],al
      push_next:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	push_reg
	cmp	al,'('
	je	push_imm
	cmp	al,'['
	jne	invalid_operand
      push_mem:
	call	get_address
	mov	al,[operand_size]
	mov	ah,[push_size]
	cmp	al,2
	je	push_mem_16bit
	cmp	al,4
	je	push_mem_32bit
	cmp	al,8
	je	push_mem_64bit
	or	al,al
	jnz	invalid_operand_size
	cmp	ah,2
	je	push_mem_16bit
	cmp	ah,4
	je	push_mem_32bit
	cmp	ah,8
	je	push_mem_64bit
	call	recoverable_unknown_size
	jmp	push_mem_store
      push_mem_16bit:
	test	ah,not 2
	jnz	invalid_operand_size
	call	operand_16bit
	jmp	push_mem_store
      push_mem_32bit:
	test	ah,not 4
	jnz	invalid_operand_size
	cmp	[code_type],64
	je	illegal_instruction
	call	operand_32bit
	jmp	push_mem_store
      push_mem_64bit:
	test	ah,not 8
	jnz	invalid_operand_size
	cmp	[code_type],64
	jne	illegal_instruction
      push_mem_store:
	mov	[base_code],0FFh
	mov	[postbyte_register],110b
	call	store_instruction
	jmp	push_done
      push_reg:
	lods	byte [esi]
	mov	ah,al
	sub	ah,10h
	and	ah,al
	test	ah,0F0h
	jnz	push_sreg
	call	convert_register
	test	al,1000b
	jz	push_reg_ok
	or	[rex_prefix],41h
	and	al,111b
      push_reg_ok:
	add	al,50h
	mov	[base_code],al
	mov	al,ah
	mov	ah,[push_size]
	cmp	al,2
	je	push_reg_16bit
	cmp	al,4
	je	push_reg_32bit
	cmp	al,8
	jne	invalid_operand_size
      push_reg_64bit:
	test	ah,not 8
	jnz	invalid_operand_size
	cmp	[code_type],64
	jne	illegal_instruction
	jmp	push_reg_store
      push_reg_32bit:
	test	ah,not 4
	jnz	invalid_operand_size
	cmp	[code_type],64
	je	illegal_instruction
	call	operand_32bit
	jmp	push_reg_store
      push_reg_16bit:
	test	ah,not 2
	jnz	invalid_operand_size
	call	operand_16bit
      push_reg_store:
	call	store_classic_instruction_code
	jmp	push_done
      push_sreg:
	mov	bl,al
	mov	dl,[operand_size]
	mov	dh,[push_size]
	cmp	dl,2
	je	push_sreg16
	cmp	dl,4
	je	push_sreg32
	cmp	dl,8
	je	push_sreg64
	or	dl,dl
	jnz	invalid_operand_size
	cmp	dh,2
	je	push_sreg16
	cmp	dh,4
	je	push_sreg32
	cmp	dh,8
	je	push_sreg64
	jmp	push_sreg_store
      push_sreg16:
	test	dh,not 2
	jnz	invalid_operand_size
	call	operand_16bit
	jmp	push_sreg_store
      push_sreg32:
	test	dh,not 4
	jnz	invalid_operand_size
	cmp	[code_type],64
	je	illegal_instruction
	call	operand_32bit
	jmp	push_sreg_store
      push_sreg64:
	test	dh,not 8
	jnz	invalid_operand_size
	cmp	[code_type],64
	jne	illegal_instruction
      push_sreg_store:
	mov	al,bl
	cmp	al,40h
	jae	invalid_operand
	sub	al,31h
	jc	invalid_operand
	cmp	al,4
	jae	push_sreg_386
	shl	al,3
	add	al,6
	mov	[base_code],al
	cmp	[code_type],64
	je	illegal_instruction
	jmp	push_reg_store
      push_sreg_386:
	sub	al,4
	shl	al,3
	add	al,0A0h
	mov	[extended_code],al
	mov	[base_code],0Fh
	jmp	push_reg_store
      push_imm:
	mov	al,[operand_size]
	mov	ah,[push_size]
	or	al,al
	je	push_imm_size_ok
	or	ah,ah
	je	push_imm_size_ok
	cmp	al,ah
	jne	invalid_operand_size
      push_imm_size_ok:
	cmp	al,2
	je	push_imm_16bit
	cmp	al,4
	je	push_imm_32bit
	cmp	al,8
	je	push_imm_64bit
	cmp	ah,2
	je	push_imm_optimized_16bit
	cmp	ah,4
	je	push_imm_optimized_32bit
	cmp	ah,8
	je	push_imm_optimized_64bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[code_type],16
	je	push_imm_optimized_16bit
	cmp	[code_type],32
	je	push_imm_optimized_32bit
      push_imm_optimized_64bit:
	cmp	[code_type],64
	jne	illegal_instruction
	call	get_simm32
	mov	edx,eax
	cmp	[value_type],0
	jne	push_imm_32bit_store
	cmp	eax,-80h
	jl	push_imm_32bit_store
	cmp	eax,80h
	jge	push_imm_32bit_store
	jmp	push_imm_8bit
      push_imm_optimized_32bit:
	cmp	[code_type],64
	je	illegal_instruction
	call	get_dword_value
	mov	edx,eax
	call	operand_32bit
	cmp	[value_type],0
	jne	push_imm_32bit_store
	cmp	eax,-80h
	jl	push_imm_32bit_store
	cmp	eax,80h
	jge	push_imm_32bit_store
	jmp	push_imm_8bit
      push_imm_optimized_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit
	cmp	[value_type],0
	jne	push_imm_16bit_store
	cmp	ax,-80h
	jl	push_imm_16bit_store
	cmp	ax,80h
	jge	push_imm_16bit_store
      push_imm_8bit:
	mov	ah,al
	mov	[base_code],6Ah
	call	store_classic_instruction_code
	mov	al,ah
	stos	byte [edi]
	jmp	push_done
      push_imm_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit
      push_imm_16bit_store:
	mov	[base_code],68h
	call	store_classic_instruction_code
	mov	ax,dx
	call	mark_relocation
	stos	word [edi]
	jmp	push_done
      push_imm_64bit:
	cmp	[code_type],64
	jne	illegal_instruction
	call	get_simm32
	mov	edx,eax
	jmp	push_imm_32bit_store
      push_imm_32bit:
	cmp	[code_type],64
	je	illegal_instruction
	call	get_dword_value
	mov	edx,eax
	call	operand_32bit
      push_imm_32bit_store:
	mov	[base_code],68h
	call	store_classic_instruction_code
	mov	eax,edx
	call	mark_relocation
	stos	dword [edi]
      push_done:
	lods	byte [esi]
	dec	esi
	cmp	al,0Fh
	je	instruction_assembled
	or	al,al
	jz	instruction_assembled
#	 mov	 [operand_size],0
#	 mov	 [operand_flags],0
#	 mov	 [operand_prefix],0
#	 mov	 [rex_prefix],0
	and	dword [operand_size],0
	jmp	push_next
pop_instruction:
	mov	[push_size],al
      pop_next:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	pop_reg
	cmp	al,'['
	jne	invalid_operand
      pop_mem:
	call	get_address
	mov	al,[operand_size]
	mov	ah,[push_size]
	cmp	al,2
	je	pop_mem_16bit
	cmp	al,4
	je	pop_mem_32bit
	cmp	al,8
	je	pop_mem_64bit
	or	al,al
	jnz	invalid_operand_size
	cmp	ah,2
	je	pop_mem_16bit
	cmp	ah,4
	je	pop_mem_32bit
	cmp	ah,8
	je	pop_mem_64bit
	call	recoverable_unknown_size
	jmp	pop_mem_store
      pop_mem_16bit:
	test	ah,not 2
	jnz	invalid_operand_size
	call	operand_16bit
	jmp	pop_mem_store
      pop_mem_32bit:
	test	ah,not 4
	jnz	invalid_operand_size
	cmp	[code_type],64
	je	illegal_instruction
	call	operand_32bit
	jmp	pop_mem_store
      pop_mem_64bit:
	test	ah,not 8
	jnz	invalid_operand_size
	cmp	[code_type],64
	jne	illegal_instruction
      pop_mem_store:
	mov	[base_code],08Fh
	mov	[postbyte_register],0
	call	store_instruction
	jmp	pop_done
      pop_reg:
	lods	byte [esi]
	mov	ah,al
	sub	ah,10h
	and	ah,al
	test	ah,0F0h
	jnz	pop_sreg
	call	convert_register
	test	al,1000b
	jz	pop_reg_ok
	or	[rex_prefix],41h
	and	al,111b
      pop_reg_ok:
	add	al,58h
	mov	[base_code],al
	mov	al,ah
	mov	ah,[push_size]
	cmp	al,2
	je	pop_reg_16bit
	cmp	al,4
	je	pop_reg_32bit
	cmp	al,8
	je	pop_reg_64bit
	jmp	invalid_operand_size
      pop_reg_64bit:
	test	ah,not 8
	jnz	invalid_operand_size
	cmp	[code_type],64
	jne	illegal_instruction
	jmp	pop_reg_store
      pop_reg_32bit:
	test	ah,not 4
	jnz	invalid_operand_size
	cmp	[code_type],64
	je	illegal_instruction
	call	operand_32bit
	jmp	pop_reg_store
      pop_reg_16bit:
	test	ah,not 2
	jnz	invalid_operand_size
	call	operand_16bit
      pop_reg_store:
	call	store_classic_instruction_code
      pop_done:
	lods	byte [esi]
	dec	esi
	cmp	al,0Fh
	je	instruction_assembled
	or	al,al
	jz	instruction_assembled
#	 mov	 [operand_size],0
#	 mov	 [operand_flags],0
#	 mov	 [operand_prefix],0
#	 mov	 [rex_prefix],0
	and	dword [operand_size],0
	jmp	pop_next
      pop_sreg:
	mov	dl,[operand_size]
	mov	dh,[push_size]
	cmp	al,32h
	je	pop_cs
	mov	bl,al
	cmp	dl,2
	je	pop_sreg16
	cmp	dl,4
	je	pop_sreg32
	cmp	dl,8
	je	pop_sreg64
	or	dl,dl
	jnz	invalid_operand_size
	cmp	dh,2
	je	pop_sreg16
	cmp	dh,4
	je	pop_sreg32
	cmp	dh,8
	je	pop_sreg64
	jmp	pop_sreg_store
      pop_sreg16:
	test	dh,not 2
	jnz	invalid_operand_size
	call	operand_16bit
	jmp	pop_sreg_store
      pop_sreg32:
	test	dh,not 4
	jnz	invalid_operand_size
	cmp	[code_type],64
	je	illegal_instruction
	call	operand_32bit
	jmp	pop_sreg_store
      pop_sreg64:
	test	dh,not 8
	jnz	invalid_operand_size
	cmp	[code_type],64
	jne	illegal_instruction
      pop_sreg_store:
	mov	al,bl
	cmp	al,40h
	jae	invalid_operand
	sub	al,31h
	jc	invalid_operand
	cmp	al,4
	jae	pop_sreg_386
	shl	al,3
	add	al,7
	mov	[base_code],al
	cmp	[code_type],64
	je	illegal_instruction
	jmp	pop_reg_store
      pop_cs:
	cmp	[code_type],16
	jne	illegal_instruction
	cmp	dl,2
	je	pop_cs_store
	or	dl,dl
	jnz	invalid_operand_size
	cmp	dh,2
	je	pop_cs_store
	or	dh,dh
	jnz	illegal_instruction
      pop_cs_store:
	test	dh,not 2
	jnz	invalid_operand_size
	mov	al,0Fh
	stos	byte [edi]
	jmp	pop_done
      pop_sreg_386:
	sub	al,4
	shl	al,3
	add	al,0A1h
	mov	[extended_code],al
	mov	[base_code],0Fh
	jmp	pop_reg_store
inc_instruction:
	mov	[base_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	inc_reg
	cmp	al,'['
	je	inc_mem
	jne	invalid_operand
      inc_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	inc_mem_8bit
	jb	inc_mem_nosize
	call	operand_autodetect
	mov	al,0FFh
	xchg	al,[base_code]
	mov	[postbyte_register],al
	jmp	instruction_ready
      inc_mem_nosize:
	call	recoverable_unknown_size
      inc_mem_8bit:
	mov	al,0FEh
	xchg	al,[base_code]
	mov	[postbyte_register],al
	jmp	instruction_ready
      inc_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,0FEh
	xchg	al,[base_code]
	mov	[postbyte_register],al
	mov	al,ah
	cmp	al,1
	je	inc_reg_8bit
	call	operand_autodetect
	cmp	[code_type],64
	je	inc_reg_long_form
	mov	al,[postbyte_register]
	shl	al,3
	add	al,bl
	add	al,40h
	mov	[base_code],al
	call	store_classic_instruction_code
	jmp	instruction_assembled
      inc_reg_long_form:
	inc	[base_code]
      inc_reg_8bit:
	jmp	nomem_instruction_ready
set_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	set_reg
	cmp	al,'['
	jne	invalid_operand
      set_mem:
	call	get_address
	cmp	[operand_size],1
	ja	invalid_operand_size
	mov	[postbyte_register],0
	jmp	instruction_ready
      set_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ah,1
	jne	invalid_operand_size
	mov	bl,al
	mov	[postbyte_register],0
	jmp	nomem_instruction_ready
arpl_instruction:
	cmp	[code_type],64
	je	illegal_instruction
	mov	[base_code],63h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	arpl_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	[postbyte_register],al
	cmp	ah,2
	jne	invalid_operand_size
	jmp	instruction_ready
      arpl_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ah,2
	jne	invalid_operand_size
	mov	bl,al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	[postbyte_register],al
	jmp	nomem_instruction_ready
bound_instruction:
	cmp	[code_type],64
	je	illegal_instruction
	call	take_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	bound_store
	cmp	al,4
	jne	invalid_operand_size
      bound_store:
	call	operand_autodetect
	mov	[base_code],62h
	jmp	instruction_ready
enter_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	ah,2
	je	enter_imm16_size_ok
	or	ah,ah
	jnz	invalid_operand_size
      enter_imm16_size_ok:
	cmp	al,'('
	jne	invalid_operand
	call	get_word_value
	cmp	[next_pass_needed],0
	jne	enter_imm16_ok
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	test	eax,eax
	js	value_out_of_range
      enter_imm16_ok:
	push	eax
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	ah,1
	je	enter_imm8_size_ok
	or	ah,ah
	jnz	invalid_operand_size
      enter_imm8_size_ok:
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	cmp	[next_pass_needed],0
	jne	enter_imm8_ok
	test	eax,eax
	js	value_out_of_range
      enter_imm8_ok:
	mov	dl,al
	pop	ebx
	mov	al,0C8h
	stos	byte [edi]
	mov	ax,bx
	stos	word [edi]
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
ret_instruction_only64:
	cmp	[code_type],64
	jne	illegal_instruction
	jmp	ret_instruction
ret_instruction_32bit_except64:
	cmp	[code_type],64
	je	illegal_instruction
ret_instruction_32bit:
	call	operand_32bit
	jmp	ret_instruction
ret_instruction_16bit:
	call	operand_16bit
	jmp	ret_instruction
ret_instruction_64bit:
	call	operand_64bit
ret_instruction:
	and	[prefix_flags],not 10h
      ret_common:
	mov	[base_code],al
	lods	byte [esi]
	dec	esi
	or	al,al
	jz	simple_ret
	cmp	al,0Fh
	je	simple_ret
	lods	byte [esi]
	call	get_size_operator
	or	ah,ah
	jz	ret_imm
	cmp	ah,2
	je	ret_imm
	jmp	invalid_operand_size
      ret_imm:
	cmp	al,'('
	jne	invalid_operand
	call	get_word_value
	cmp	[next_pass_needed],0
	jne	ret_imm_ok
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	test	eax,eax
	js	value_out_of_range
      ret_imm_ok:
	cmp	[size_declared],0
	jne	ret_imm_store
	or	ax,ax
	jz	simple_ret
      ret_imm_store:
	mov	dx,ax
	call	store_classic_instruction_code
	mov	ax,dx
	stos	word [edi]
	jmp	instruction_assembled
      simple_ret:
	inc	[base_code]
	call	store_classic_instruction_code
	jmp	instruction_assembled
retf_instruction:
	cmp	[code_type],64
	jne	ret_common
retf_instruction_64bit:
	call	operand_64bit
	jmp	ret_common
retf_instruction_32bit:
	call	operand_32bit
	jmp	ret_common
retf_instruction_16bit:
	call	operand_16bit
	jmp	ret_common
lea_instruction:
	mov	[base_code],8Dh
	call	take_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	al,al
	xchg	al,[operand_size]
	push	eax
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	or	[operand_flags],1
	call	get_address
	pop	eax
	mov	[operand_size],al
	call	operand_autodetect
	jmp	instruction_ready
ls_instruction:
	or	al,al
	jz	les_instruction
	cmp	al,3
	jz	lds_instruction
	add	al,0B0h
	mov	[extended_code],al
	mov	[base_code],0Fh
	jmp	ls_code_ok
      les_instruction:
	mov	[base_code],0C4h
	jmp	ls_short_code
      lds_instruction:
	mov	[base_code],0C5h
      ls_short_code:
	cmp	[code_type],64
	je	illegal_instruction
      ls_code_ok:
	call	take_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	add	[operand_size],2
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,4
	je	ls_16bit
	cmp	al,6
	je	ls_32bit
	cmp	al,10
	je	ls_64bit
	jmp	invalid_operand_size
      ls_16bit:
	call	operand_16bit
	jmp	instruction_ready
      ls_32bit:
	call	operand_32bit
	jmp	instruction_ready
      ls_64bit:
	call	operand_64bit
	jmp	instruction_ready
sh_instruction:
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	sh_reg
	cmp	al,'['
	jne	invalid_operand
      sh_mem:
	call	get_address
	push	edx ebx ecx
	mov	al,[operand_size]
	push	eax
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	sh_mem_imm
	cmp	al,10h
	jne	invalid_operand
      sh_mem_reg:
	lods	byte [esi]
	cmp	al,11h
	jne	invalid_operand
	pop	eax ecx ebx edx
	cmp	al,1
	je	sh_mem_cl_8bit
	jb	sh_mem_cl_nosize
	call	operand_autodetect
	mov	[base_code],0D3h
	jmp	instruction_ready
      sh_mem_cl_nosize:
	call	recoverable_unknown_size
      sh_mem_cl_8bit:
	mov	[base_code],0D2h
	jmp	instruction_ready
      sh_mem_imm:
	mov	al,[operand_size]
	or	al,al
	jz	sh_mem_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      sh_mem_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	eax ecx ebx edx
	cmp	al,1
	je	sh_mem_imm_8bit
	jb	sh_mem_imm_nosize
	call	operand_autodetect
	cmp	byte [value],1
	je	sh_mem_1
	mov	[base_code],0C1h
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      sh_mem_1:
	mov	[base_code],0D1h
	jmp	instruction_ready
      sh_mem_imm_nosize:
	call	recoverable_unknown_size
      sh_mem_imm_8bit:
	cmp	byte [value],1
	je	sh_mem_1_8bit
	mov	[base_code],0C0h
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      sh_mem_1_8bit:
	mov	[base_code],0D0h
	jmp	instruction_ready
      sh_reg:
	lods	byte [esi]
	call	convert_register
	mov	bx,ax
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	sh_reg_imm
	cmp	al,10h
	jne	invalid_operand
      sh_reg_reg:
	lods	byte [esi]
	cmp	al,11h
	jne	invalid_operand
	mov	al,bh
	cmp	al,1
	je	sh_reg_cl_8bit
	call	operand_autodetect
	mov	[base_code],0D3h
	jmp	nomem_instruction_ready
      sh_reg_cl_8bit:
	mov	[base_code],0D2h
	jmp	nomem_instruction_ready
      sh_reg_imm:
	mov	al,[operand_size]
	or	al,al
	jz	sh_reg_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      sh_reg_imm_size_ok:
	push	ebx
	call	get_byte_value
	mov	dl,al
	pop	ebx
	mov	al,bh
	cmp	al,1
	je	sh_reg_imm_8bit
	call	operand_autodetect
	cmp	dl,1
	je	sh_reg_1
	mov	[base_code],0C1h
	call	store_nomem_instruction
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      sh_reg_1:
	mov	[base_code],0D1h
	jmp	nomem_instruction_ready
      sh_reg_imm_8bit:
	cmp	dl,1
	je	sh_reg_1_8bit
	mov	[base_code],0C0h
	call	store_nomem_instruction
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      sh_reg_1_8bit:
	mov	[base_code],0D0h
	jmp	nomem_instruction_ready
shd_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	shd_reg
	cmp	al,'['
	jne	invalid_operand
      shd_mem:
	call	get_address
	push	edx ebx ecx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	al,ah
	mov	[operand_size],0
	push	eax
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	shd_mem_reg_imm
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,11h
	jne	invalid_operand
	pop	eax ecx ebx edx
	call	operand_autodetect
	inc	[extended_code]
	jmp	instruction_ready
      shd_mem_reg_imm:
	mov	al,[operand_size]
	or	al,al
	jz	shd_mem_reg_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      shd_mem_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	eax ecx ebx edx
	call	operand_autodetect
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      shd_reg:
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	bl,[postbyte_register]
	mov	[postbyte_register],al
	mov	al,ah
	push	eax ebx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	shd_reg_reg_imm
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,11h
	jne	invalid_operand
	pop	ebx eax
	call	operand_autodetect
	inc	[extended_code]
	jmp	nomem_instruction_ready
      shd_reg_reg_imm:
	mov	al,[operand_size]
	or	al,al
	jz	shd_reg_reg_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      shd_reg_reg_imm_size_ok:
	call	get_byte_value
	mov	dl,al
	pop	ebx eax
	call	operand_autodetect
	call	store_nomem_instruction
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
movx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	call	take_register
	mov	[postbyte_register],al
	mov	al,ah
	push	eax
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	movx_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop	eax
	mov	ah,[operand_size]
	or	ah,ah
	jz	movx_unknown_size
	cmp	ah,al
	jae	invalid_operand_size
	cmp	ah,1
	je	movx_mem_store
	cmp	ah,2
	jne	invalid_operand_size
	inc	[extended_code]
      movx_mem_store:
	call	operand_autodetect
	jmp	instruction_ready
      movx_unknown_size:
	call	recoverable_unknown_size
	jmp	movx_mem_store
      movx_reg:
	lods	byte [esi]
	call	convert_register
	pop	ebx
	xchg	bl,al
	cmp	ah,al
	jae	invalid_operand_size
	cmp	ah,1
	je	movx_reg_8bit
	cmp	ah,2
	je	movx_reg_16bit
	jmp	invalid_operand_size
      movx_reg_8bit:
	call	operand_autodetect
	jmp	nomem_instruction_ready
      movx_reg_16bit:
	call	operand_autodetect
	inc	[extended_code]
	jmp	nomem_instruction_ready
movsxd_instruction:
	mov	[base_code],al
	call	take_register
	mov	[postbyte_register],al
	cmp	ah,8
	jne	invalid_operand_size
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	movsxd_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],4
	je	movsxd_mem_store
	cmp	[operand_size],0
	jne	invalid_operand_size
      movsxd_mem_store:
	call	operand_64bit
	jmp	instruction_ready
      movsxd_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	bl,al
	call	operand_64bit
	jmp	nomem_instruction_ready
bt_instruction:
	mov	[postbyte_register],al
	shl	al,3
	add	al,83h
	mov	[extended_code],al
	mov	[base_code],0Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	bt_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	push	eax ebx ecx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	cmp	byte [esi],'('
	je	bt_mem_imm
	cmp	byte [esi],11h
	jne	bt_mem_reg
	cmp	byte [esi+2],'('
	je	bt_mem_imm
      bt_mem_reg:
	call	take_register
	mov	[postbyte_register],al
	pop	ecx ebx edx
	mov	al,ah
	call	operand_autodetect
	jmp	instruction_ready
      bt_mem_imm:
	xor	al,al
	xchg	al,[operand_size]
	push	eax
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	mov	al,[operand_size]
	or	al,al
	jz	bt_mem_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      bt_mem_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	eax
	or	al,al
	jz	bt_mem_imm_nosize
	call	operand_autodetect
      bt_mem_imm_store:
	pop	ecx ebx edx
	mov	[extended_code],0BAh
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      bt_mem_imm_nosize:
	call	recoverable_unknown_size
	jmp	bt_mem_imm_store
      bt_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	cmp	byte [esi],'('
	je	bt_reg_imm
	cmp	byte [esi],11h
	jne	bt_reg_reg
	cmp	byte [esi+2],'('
	je	bt_reg_imm
      bt_reg_reg:
	call	take_register
	mov	[postbyte_register],al
	mov	al,ah
	call	operand_autodetect
	jmp	nomem_instruction_ready
      bt_reg_imm:
	xor	al,al
	xchg	al,[operand_size]
	push	eax ebx
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	mov	al,[operand_size]
	or	al,al
	jz	bt_reg_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      bt_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	ebx eax
	call	operand_autodetect
      bt_reg_imm_store:
	mov	[extended_code],0BAh
	call	store_nomem_instruction
	mov	al,byte [value]
	stos	byte [edi]
	jmp	instruction_assembled
bs_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	call	get_reg_mem
	jc	bs_reg_reg
	mov	al,[operand_size]
	call	operand_autodetect
	jmp	instruction_ready
      bs_reg_reg:
	mov	al,ah
	call	operand_autodetect
	jmp	nomem_instruction_ready
      get_reg_mem:
	call	take_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	get_reg_reg
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	clc
	ret
      get_reg_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	stc
	ret

imul_instruction:
	mov	[base_code],0F6h
	mov	[postbyte_register],5
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	imul_reg
	cmp	al,'['
	jne	invalid_operand
      imul_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	imul_mem_8bit
	jb	imul_mem_nosize
	call	operand_autodetect
	inc	[base_code]
	jmp	instruction_ready
      imul_mem_nosize:
	call	recoverable_unknown_size
      imul_mem_8bit:
	jmp	instruction_ready
      imul_reg:
	lods	byte [esi]
	call	convert_register
	cmp	byte [esi],','
	je	imul_reg_
	mov	bl,al
	mov	al,ah
	cmp	al,1
	je	imul_reg_8bit
	call	operand_autodetect
	inc	[base_code]
      imul_reg_8bit:
	jmp	nomem_instruction_ready
      imul_reg_:
	mov	[postbyte_register],al
	inc	esi
	cmp	byte [esi],'('
	je	imul_reg_imm
	cmp	byte [esi],11h
	jne	imul_reg_noimm
	cmp	byte [esi+2],'('
	je	imul_reg_imm
      imul_reg_noimm:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	imul_reg_reg
	cmp	al,'['
	jne	invalid_operand
      imul_reg_mem:
	call	get_address
	push	edx ebx ecx
	cmp	byte [esi],','
	je	imul_reg_mem_imm
	mov	al,[operand_size]
	call	operand_autodetect
	pop	ecx ebx edx
	mov	[base_code],0Fh
	mov	[extended_code],0AFh
	jmp	instruction_ready
      imul_reg_mem_imm:
	inc	esi
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	mov	al,[operand_size]
	cmp	al,2
	je	imul_reg_mem_imm_16bit
	cmp	al,4
	je	imul_reg_mem_imm_32bit
	cmp	al,8
	jne	invalid_operand_size
      imul_reg_mem_imm_64bit:
	cmp	[size_declared],0
	jne	long_immediate_not_encodable
	call	operand_64bit
	call	get_simm32
	cmp	[value_type],4
	jae	long_immediate_not_encodable
	jmp	imul_reg_mem_imm_32bit_ok
      imul_reg_mem_imm_16bit:
	call	operand_16bit
	call	get_word_value
	mov	word [value],ax
	cmp	[value_type],0
	jne	imul_reg_mem_imm_16bit_store
	cmp	[size_declared],0
	jne	imul_reg_mem_imm_16bit_store
	cmp	ax,-80h
	jl	imul_reg_mem_imm_16bit_store
	cmp	ax,80h
	jl	imul_reg_mem_imm_8bit_store
      imul_reg_mem_imm_16bit_store:
	pop	ecx ebx edx
	mov	[base_code],69h
	call	store_instruction_with_imm16
	jmp	instruction_assembled
      imul_reg_mem_imm_32bit:
	call	operand_32bit
	call	get_dword_value
      imul_reg_mem_imm_32bit_ok:
	mov	dword [value],eax
	cmp	[value_type],0
	jne	imul_reg_mem_imm_32bit_store
	cmp	[size_declared],0
	jne	imul_reg_mem_imm_32bit_store
	cmp	eax,-80h
	jl	imul_reg_mem_imm_32bit_store
	cmp	eax,80h
	jl	imul_reg_mem_imm_8bit_store
      imul_reg_mem_imm_32bit_store:
	pop	ecx ebx edx
	mov	[base_code],69h
	call	store_instruction_with_imm32
	jmp	instruction_assembled
      imul_reg_mem_imm_8bit_store:
	pop	ecx ebx edx
	mov	[base_code],6Bh
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      imul_reg_imm:
	mov	bl,[postbyte_register]
	dec	esi
	jmp	imul_reg_reg_imm
      imul_reg_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	cmp	byte [esi],','
	je	imul_reg_reg_imm
	mov	al,ah
	call	operand_autodetect
	mov	[base_code],0Fh
	mov	[extended_code],0AFh
	jmp	nomem_instruction_ready
      imul_reg_reg_imm:
	inc	esi
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	mov	al,[operand_size]
	cmp	al,2
	je	imul_reg_reg_imm_16bit
	cmp	al,4
	je	imul_reg_reg_imm_32bit
	cmp	al,8
	jne	invalid_operand_size
      imul_reg_reg_imm_64bit:
	cmp	[size_declared],0
	jne	long_immediate_not_encodable
	call	operand_64bit
	push	ebx
	call	get_simm32
	cmp	[value_type],4
	jae	long_immediate_not_encodable
	jmp	imul_reg_reg_imm_32bit_ok
      imul_reg_reg_imm_16bit:
	call	operand_16bit
	push	ebx
	call	get_word_value
	pop	ebx
	mov	dx,ax
	cmp	[value_type],0
	jne	imul_reg_reg_imm_16bit_store
	cmp	[size_declared],0
	jne	imul_reg_reg_imm_16bit_store
	cmp	ax,-80h
	jl	imul_reg_reg_imm_16bit_store
	cmp	ax,80h
	jl	imul_reg_reg_imm_8bit_store
      imul_reg_reg_imm_16bit_store:
	mov	[base_code],69h
	call	store_nomem_instruction
	mov	ax,dx
	call	mark_relocation
	stos	word [edi]
	jmp	instruction_assembled
      imul_reg_reg_imm_32bit:
	call	operand_32bit
	push	ebx
	call	get_dword_value
      imul_reg_reg_imm_32bit_ok:
	pop	ebx
	mov	edx,eax
	cmp	[value_type],0
	jne	imul_reg_reg_imm_32bit_store
	cmp	[size_declared],0
	jne	imul_reg_reg_imm_32bit_store
	cmp	eax,-80h
	jl	imul_reg_reg_imm_32bit_store
	cmp	eax,80h
	jl	imul_reg_reg_imm_8bit_store
      imul_reg_reg_imm_32bit_store:
	mov	[base_code],69h
	call	store_nomem_instruction
	mov	eax,edx
	call	mark_relocation
	stos	dword [edi]
	jmp	instruction_assembled
      imul_reg_reg_imm_8bit_store:
	mov	[base_code],6Bh
	call	store_nomem_instruction
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
in_instruction:
	call	take_register
	or	al,al
	jnz	invalid_operand
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	al,ah
	push	eax
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	in_imm
	cmp	al,10h
	je	in_reg
	jmp	invalid_operand
      in_reg:
	lods	byte [esi]
	cmp	al,22h
	jne	invalid_operand
	pop	eax
	cmp	al,1
	je	in_al_dx
	cmp	al,2
	je	in_ax_dx
	cmp	al,4
	jne	invalid_operand_size
      in_ax_dx:
	call	operand_autodetect
	mov	[base_code],0EDh
	call	store_classic_instruction_code
	jmp	instruction_assembled
      in_al_dx:
	mov	al,0ECh
	stos	byte [edi]
	jmp	instruction_assembled
      in_imm:
	mov	al,[operand_size]
	or	al,al
	jz	in_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      in_imm_size_ok:
	call	get_byte_value
	mov	dl,al
	pop	eax
	cmp	al,1
	je	in_al_imm
	cmp	al,2
	je	in_ax_imm
	cmp	al,4
	jne	invalid_operand_size
      in_ax_imm:
	call	operand_autodetect
	mov	[base_code],0E5h
	call	store_classic_instruction_code
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      in_al_imm:
	mov	al,0E4h
	stos	byte [edi]
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
out_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'('
	je	out_imm
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,22h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	call	take_register
	or	al,al
	jnz	invalid_operand
	mov	al,ah
	cmp	al,1
	je	out_dx_al
	cmp	al,2
	je	out_dx_ax
	cmp	al,4
	jne	invalid_operand_size
      out_dx_ax:
	call	operand_autodetect
	mov	[base_code],0EFh
	call	store_classic_instruction_code
	jmp	instruction_assembled
      out_dx_al:
	mov	al,0EEh
	stos	byte [edi]
	jmp	instruction_assembled
      out_imm:
	mov	al,[operand_size]
	or	al,al
	jz	out_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      out_imm_size_ok:
	call	get_byte_value
	mov	dl,al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	call	take_register
	or	al,al
	jnz	invalid_operand
	mov	al,ah
	cmp	al,1
	je	out_imm_al
	cmp	al,2
	je	out_imm_ax
	cmp	al,4
	jne	invalid_operand_size
      out_imm_ax:
	call	operand_autodetect
	mov	[base_code],0E7h
	call	store_classic_instruction_code
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
      out_imm_al:
	mov	al,0E6h
	stos	byte [edi]
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled

call_instruction:
	mov	[postbyte_register],10b
	mov	[base_code],0E8h
	mov	[extended_code],9Ah
	jmp	process_jmp
jmp_instruction:
	mov	[postbyte_register],100b
	mov	[base_code],0E9h
	mov	[extended_code],0EAh
      process_jmp:
	lods	byte [esi]
	call	get_jump_operator
	test	[prefix_flags],10h
	jz	jmp_type_ok
	test	[jump_type],not 2
	jnz	illegal_instruction
	mov	[jump_type],2
	and	[prefix_flags],not 10h
      jmp_type_ok:
	call	get_size_operator
	cmp	al,'('
	je	jmp_imm
	mov	[base_code],0FFh
	cmp	al,10h
	je	jmp_reg
	cmp	al,'['
	jne	invalid_operand
      jmp_mem:
	cmp	[jump_type],1
	je	illegal_instruction
	call	get_address
	mov	edx,eax
	mov	al,[operand_size]
	or	al,al
	jz	jmp_mem_size_not_specified
	cmp	al,2
	je	jmp_mem_16bit
	cmp	al,4
	je	jmp_mem_32bit
	cmp	al,6
	je	jmp_mem_48bit
	cmp	al,8
	je	jmp_mem_64bit
	cmp	al,10
	je	jmp_mem_80bit
	jmp	invalid_operand_size
      jmp_mem_size_not_specified:
	cmp	[jump_type],3
	je	jmp_mem_far
	cmp	[jump_type],2
	je	jmp_mem_near
	call	recoverable_unknown_size
      jmp_mem_near:
	cmp	[code_type],16
	je	jmp_mem_16bit
	cmp	[code_type],32
	je	jmp_mem_near_32bit
      jmp_mem_64bit:
	cmp	[jump_type],3
	je	invalid_operand_size
	cmp	[code_type],64
	jne	illegal_instruction
	jmp	instruction_ready
      jmp_mem_far:
	cmp	[code_type],16
	je	jmp_mem_far_32bit
      jmp_mem_48bit:
	call	operand_32bit
      jmp_mem_far_store:
	cmp	[jump_type],2
	je	invalid_operand_size
	inc	[postbyte_register]
	jmp	instruction_ready
      jmp_mem_80bit:
	call	operand_64bit
	jmp	jmp_mem_far_store
      jmp_mem_far_32bit:
	call	operand_16bit
	jmp	jmp_mem_far_store
      jmp_mem_32bit:
	cmp	[jump_type],3
	je	jmp_mem_far_32bit
	cmp	[jump_type],2
	je	jmp_mem_near_32bit
	cmp	[code_type],16
	je	jmp_mem_far_32bit
      jmp_mem_near_32bit:
	cmp	[code_type],64
	je	illegal_instruction
	call	operand_32bit
	jmp	instruction_ready
      jmp_mem_16bit:
	cmp	[jump_type],3
	je	invalid_operand_size
	call	operand_16bit
	jmp	instruction_ready
      jmp_reg:
	test	[jump_type],1
	jnz	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,ah
	cmp	al,2
	je	jmp_reg_16bit
	cmp	al,4
	je	jmp_reg_32bit
	cmp	al,8
	jne	invalid_operand_size
      jmp_reg_64bit:
	cmp	[code_type],64
	jne	illegal_instruction
	jmp	nomem_instruction_ready
      jmp_reg_32bit:
	cmp	[code_type],64
	je	illegal_instruction
	call	operand_32bit
	jmp	nomem_instruction_ready
      jmp_reg_16bit:
	call	operand_16bit
	jmp	nomem_instruction_ready
      jmp_imm:
	cmp	byte [esi],'.'
	je	invalid_value
	mov	ebx,esi
	dec	esi
	call	skip_symbol
	xchg	esi,ebx
	cmp	byte [ebx],':'
	je	jmp_far
	cmp	[jump_type],3
	je	invalid_operand
      jmp_near:
	mov	al,[operand_size]
	cmp	al,2
	je	jmp_imm_16bit
	cmp	al,4
	je	jmp_imm_32bit
	cmp	al,8
	je	jmp_imm_64bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[code_type],16
	je	jmp_imm_16bit
	cmp	[code_type],64
	je	jmp_imm_64bit
      jmp_imm_32bit:
	cmp	[code_type],64
	je	invalid_operand_size
	call	get_address_dword_value
	cmp	[code_type],16
	jne	jmp_imm_32bit_prefix_ok
	mov	byte [edi],66h
	inc	edi
      jmp_imm_32bit_prefix_ok:
	call	calculate_jump_offset
	cdq
	call	check_for_short_jump
	jc	jmp_short
      jmp_imm_32bit_store:
	mov	edx,eax
	sub	edx,3
	jno	jmp_imm_32bit_ok
	cmp	[code_type],64
	je	jump_out_of_range
      jmp_imm_32bit_ok:
	mov	al,[base_code]
	stos	byte [edi]
	mov	eax,edx
	call	mark_relocation
	stos	dword [edi]
	jmp	instruction_assembled
      jmp_imm_64bit:
	cmp	[code_type],64
	jne	invalid_operand_size
	call	get_address_qword_value
	call	calculate_jump_offset
	mov	ecx,edx
	cdq
	cmp	edx,ecx
	jne	jump_out_of_range
	call	check_for_short_jump
	jnc	jmp_imm_32bit_store
      jmp_short:
	mov	ah,al
	mov	al,0EBh
	stos	word [edi]
	jmp	instruction_assembled
      jmp_imm_16bit:
	call	get_address_word_value
	cmp	[code_type],16
	je	jmp_imm_16bit_prefix_ok
	mov	byte [edi],66h
	inc	edi
      jmp_imm_16bit_prefix_ok:
	call	calculate_jump_offset
	cwde
	cdq
	call	check_for_short_jump
	jc	jmp_short
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,eax
	dec	edx
	mov	al,[base_code]
	stos	byte [edi]
	mov	eax,edx
	stos	word [edi]
	jmp	instruction_assembled
      calculate_jump_offset:
	add	edi,2
	mov	ebp,[addressing_space]
	call	calculate_relative_offset
	sub	edi,2
	ret
      check_for_short_jump:
	cmp	[jump_type],1
	je	forced_short
	ja	no_short_jump
	cmp	[base_code],0E8h
	je	no_short_jump
	cmp	[value_type],0
	jne	no_short_jump
	cmp	eax,80h
	jb	short_jump
	cmp	eax,-80h
	jae	short_jump
      no_short_jump:
	clc
	ret
      forced_short:
	cmp	[base_code],0E8h
	je	illegal_instruction
	cmp	[next_pass_needed],0
	jne	jmp_short_value_type_ok
	cmp	[value_type],0
	jne	invalid_use_of_symbol
      jmp_short_value_type_ok:
	cmp	eax,-80h
	jae	short_jump
	cmp	eax,80h
	jae	jump_out_of_range
      short_jump:
	stc
	ret
      jump_out_of_range:
	cmp	[error_line],0
	jne	instruction_assembled
	mov	eax,[current_line]
	mov	[error_line],eax
	mov	[error],relative_jump_out_of_range
	jmp	instruction_assembled
      jmp_far:
	cmp	[jump_type],2
	je	invalid_operand
	cmp	[code_type],64
	je	illegal_instruction
	mov	al,[extended_code]
	mov	[base_code],al
	call	get_word_value
	push	eax
	inc	esi
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_operand
	mov	al,[value_type]
	push	eax [symbol_identifier]
	cmp	byte [esi],'.'
	je	invalid_value
	mov	al,[operand_size]
	cmp	al,4
	je	jmp_far_16bit
	cmp	al,6
	je	jmp_far_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[code_type],16
	jne	jmp_far_32bit
      jmp_far_16bit:
	call	get_word_value
	mov	ebx,eax
	call	operand_16bit
	call	store_classic_instruction_code
	mov	ax,bx
	call	mark_relocation
	stos	word [edi]
      jmp_far_segment:
	pop	[symbol_identifier] eax
	mov	[value_type],al
	pop	eax
	call	mark_relocation
	stos	word [edi]
	jmp	instruction_assembled
      jmp_far_32bit:
	call	get_dword_value
	mov	ebx,eax
	call	operand_32bit
	call	store_classic_instruction_code
	mov	eax,ebx
	call	mark_relocation
	stos	dword [edi]
	jmp	jmp_far_segment
conditional_jump:
	mov	[base_code],al
	and	[prefix_flags],not 10h
	lods	byte [esi]
	call	get_jump_operator
	cmp	[jump_type],3
	je	invalid_operand
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	cmp	byte [esi],'.'
	je	invalid_value
	mov	al,[operand_size]
	cmp	al,2
	je	conditional_jump_16bit
	cmp	al,4
	je	conditional_jump_32bit
	cmp	al,8
	je	conditional_jump_64bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[code_type],16
	je	conditional_jump_16bit
	cmp	[code_type],64
	je	conditional_jump_64bit
      conditional_jump_32bit:
	cmp	[code_type],64
	je	invalid_operand_size
	call	get_address_dword_value
	cmp	[code_type],16
	jne	conditional_jump_32bit_prefix_ok
	mov	byte [edi],66h
	inc	edi
      conditional_jump_32bit_prefix_ok:
	call	calculate_jump_offset
	cdq
	call	check_for_short_jump
	jc	conditional_jump_short
      conditional_jump_32bit_store:
	mov	edx,eax
	sub	edx,4
	jno	conditional_jump_32bit_range_ok
	cmp	[code_type],64
	je	jump_out_of_range
      conditional_jump_32bit_range_ok:
	mov	ah,[base_code]
	add	ah,10h
	mov	al,0Fh
	stos	word [edi]
	mov	eax,edx
	call	mark_relocation
	stos	dword [edi]
	jmp	instruction_assembled
      conditional_jump_64bit:
	cmp	[code_type],64
	jne	invalid_operand_size
	call	get_address_qword_value
	call	calculate_jump_offset
	mov	ecx,edx
	cdq
	cmp	edx,ecx
	jne	jump_out_of_range
	call	check_for_short_jump
	jnc	conditional_jump_32bit_store
      conditional_jump_short:
	mov	ah,al
	mov	al,[base_code]
	stos	word [edi]
	jmp	instruction_assembled
      conditional_jump_16bit:
	call	get_address_word_value
	cmp	[code_type],16
	je	conditional_jump_16bit_prefix_ok
	mov	byte [edi],66h
	inc	edi
      conditional_jump_16bit_prefix_ok:
	call	calculate_jump_offset
	cwde
	cdq
	call	check_for_short_jump
	jc	conditional_jump_short
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,eax
	sub	dx,2
	mov	ah,[base_code]
	add	ah,10h
	mov	al,0Fh
	stos	word [edi]
	mov	eax,edx
	stos	word [edi]
	jmp	instruction_assembled
loop_instruction_16bit:
	cmp	[code_type],64
	je	illegal_instruction
	cmp	[code_type],16
	je	loop_instruction
	mov	[operand_prefix],67h
	jmp	loop_instruction
loop_instruction_32bit:
	cmp	[code_type],32
	je	loop_instruction
	mov	[operand_prefix],67h
      jmp     loop_instruction
loop_instruction_64bit:
	cmp	[code_type],64
	jne	illegal_instruction
loop_instruction:
	mov	[base_code],al
	lods	byte [esi]
	call	get_jump_operator
	cmp	[jump_type],1
	ja	invalid_operand
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	cmp	byte [esi],'.'
	je	invalid_value
	mov	al,[operand_size]
	cmp	al,2
	je	loop_jump_16bit
	cmp	al,4
	je	loop_jump_32bit
	cmp	al,8
	je	loop_jump_64bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[code_type],16
	je	loop_jump_16bit
	cmp	[code_type],64
	je	loop_jump_64bit
      loop_jump_32bit:
	cmp	[code_type],64
	je	invalid_operand_size
	call	get_address_dword_value
	cmp	[code_type],16
	jne	loop_jump_32bit_prefix_ok
	mov	byte [edi],66h
	inc	edi
      loop_jump_32bit_prefix_ok:
	call	loop_counter_size
	call	calculate_jump_offset
	cdq
      make_loop_jump:
	call	check_for_short_jump
	jc	conditional_jump_short
	scas	word [edi]
	jmp	jump_out_of_range
      loop_counter_size:
	cmp	[operand_prefix],0
	je	loop_counter_size_ok
	push	eax
	mov	al,[operand_prefix]
	stos	byte [edi]
	pop	eax
      loop_counter_size_ok:
	ret
      loop_jump_64bit:
	cmp	[code_type],64
	jne	invalid_operand_size
	call	get_address_qword_value
	call	loop_counter_size
	call	calculate_jump_offset
	mov	ecx,edx
	cdq
	cmp	edx,ecx
	jne	jump_out_of_range
	jmp	make_loop_jump
      loop_jump_16bit:
	call	get_address_word_value
	cmp	[code_type],16
	je	loop_jump_16bit_prefix_ok
	mov	byte [edi],66h
	inc	edi
      loop_jump_16bit_prefix_ok:
	call	loop_counter_size
	call	calculate_jump_offset
	cwde
	cdq
	jmp	make_loop_jump

movs_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	[segment_register],1
	ja	invalid_address
	push	ebx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop	edx
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	mov	al,dh
	mov	ah,bh
	shr	al,4
	shr	ah,4
	cmp	al,ah
	jne	address_sizes_do_not_agree
	and	bh,111b
	and	dh,111b
	cmp	bh,6
	jne	invalid_address
	cmp	dh,7
	jne	invalid_address
	cmp	al,2
	je	movs_address_16bit
	cmp	al,4
	je	movs_address_32bit
	cmp	[code_type],64
	jne	invalid_address_size
	jmp	movs_store
      movs_address_32bit:
	call	address_32bit_prefix
	jmp	movs_store
      movs_address_16bit:
	cmp	[code_type],64
	je	invalid_address_size
	call	address_16bit_prefix
      movs_store:
	xor	ebx,ebx
	call	store_segment_prefix_if_necessary
	mov	al,0A4h
      movs_check_size:
	mov	bl,[operand_size]
	cmp	bl,1
	je	simple_instruction
	inc	al
	cmp	bl,2
	je	simple_instruction_16bit
	cmp	bl,4
	je	simple_instruction_32bit
	cmp	bl,8
	je	simple_instruction_64bit
	or	bl,bl
	jnz	invalid_operand_size
	call	recoverable_unknown_size
	jmp	simple_instruction
lods_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,26h
	je	lods_address_16bit
	cmp	bh,46h
	je	lods_address_32bit
	cmp	bh,86h
	jne	invalid_address
	cmp	[code_type],64
	jne	invalid_address_size
	jmp	lods_store
      lods_address_32bit:
	call	address_32bit_prefix
	jmp	lods_store
      lods_address_16bit:
	cmp	[code_type],64
	je	invalid_address_size
	call	address_16bit_prefix
      lods_store:
	xor	ebx,ebx
	call	store_segment_prefix_if_necessary
	mov	al,0ACh
	jmp	movs_check_size
stos_instruction:
	mov	[base_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,27h
	je	stos_address_16bit
	cmp	bh,47h
	je	stos_address_32bit
	cmp	bh,87h
	jne	invalid_address
	cmp	[code_type],64
	jne	invalid_address_size
	jmp	stos_store
      stos_address_32bit:
	call	address_32bit_prefix
	jmp	stos_store
      stos_address_16bit:
	cmp	[code_type],64
	je	invalid_address_size
	call	address_16bit_prefix
      stos_store:
	cmp	[segment_register],1
	ja	invalid_address
	mov	al,[base_code]
	jmp	movs_check_size
cmps_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	mov	al,[segment_register]
	push	eax ebx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	pop	edx eax
	cmp	[segment_register],1
	ja	invalid_address
	mov	[segment_register],al
	mov	al,dh
	mov	ah,bh
	shr	al,4
	shr	ah,4
	cmp	al,ah
	jne	address_sizes_do_not_agree
	and	bh,111b
	and	dh,111b
	cmp	bh,7
	jne	invalid_address
	cmp	dh,6
	jne	invalid_address
	cmp	al,2
	je	cmps_address_16bit
	cmp	al,4
	je	cmps_address_32bit
	cmp	[code_type],64
	jne	invalid_address_size
	jmp	cmps_store
      cmps_address_32bit:
	call	address_32bit_prefix
	jmp	cmps_store
      cmps_address_16bit:
	cmp	[code_type],64
	je	invalid_address_size
	call	address_16bit_prefix
      cmps_store:
	xor	ebx,ebx
	call	store_segment_prefix_if_necessary
	mov	al,0A6h
	jmp	movs_check_size
ins_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,27h
	je	ins_address_16bit
	cmp	bh,47h
	je	ins_address_32bit
	cmp	bh,87h
	jne	invalid_address
	cmp	[code_type],64
	jne	invalid_address_size
	jmp	ins_store
      ins_address_32bit:
	call	address_32bit_prefix
	jmp	ins_store
      ins_address_16bit:
	cmp	[code_type],64
	je	invalid_address_size
	call	address_16bit_prefix
      ins_store:
	cmp	[segment_register],1
	ja	invalid_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,22h
	jne	invalid_operand
	mov	al,6Ch
      ins_check_size:
	cmp	[operand_size],8
	jne	movs_check_size
	jmp	invalid_operand_size
outs_instruction:
	lods	byte [esi]
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,22h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,26h
	je	outs_address_16bit
	cmp	bh,46h
	je	outs_address_32bit
	cmp	bh,86h
	jne	invalid_address
	cmp	[code_type],64
	jne	invalid_address_size
	jmp	outs_store
      outs_address_32bit:
	call	address_32bit_prefix
	jmp	outs_store
      outs_address_16bit:
	cmp	[code_type],64
	je	invalid_address_size
	call	address_16bit_prefix
      outs_store:
	xor	ebx,ebx
	call	store_segment_prefix_if_necessary
	mov	al,6Eh
	jmp	ins_check_size
xlat_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,23h
	je	xlat_address_16bit
	cmp	bh,43h
	je	xlat_address_32bit
	cmp	bh,83h
	jne	invalid_address
	cmp	[code_type],64
	jne	invalid_address_size
	jmp	xlat_store
      xlat_address_32bit:
	call	address_32bit_prefix
	jmp	xlat_store
      xlat_address_16bit:
	cmp	[code_type],64
	je	invalid_address_size
	call	address_16bit_prefix
      xlat_store:
	call	store_segment_prefix_if_necessary
	mov	al,0D7h
	cmp	[operand_size],1
	jbe	simple_instruction
	jmp	invalid_operand_size

pm_word_instruction:
	mov	ah,al
	shr	ah,4
	and	al,111b
	mov	[base_code],0Fh
	mov	[extended_code],ah
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	pm_reg
      pm_mem:
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	pm_mem_store
	or	al,al
	jnz	invalid_operand_size
      pm_mem_store:
	jmp	instruction_ready
      pm_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	cmp	ah,2
	jne	invalid_operand_size
	jmp	nomem_instruction_ready
pm_store_word_instruction:
	mov	ah,al
	shr	ah,4
	and	al,111b
	mov	[base_code],0Fh
	mov	[extended_code],ah
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	pm_mem
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,ah
	call	operand_autodetect
	jmp	nomem_instruction_ready
lgdt_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],1
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,6
	je	lgdt_mem_48bit
	cmp	al,10
	je	lgdt_mem_80bit
	or	al,al
	jnz	invalid_operand_size
	jmp	lgdt_mem_store
      lgdt_mem_80bit:
	cmp	[code_type],64
	jne	illegal_instruction
	jmp	lgdt_mem_store
      lgdt_mem_48bit:
	cmp	[code_type],64
	je	illegal_instruction
	cmp	[postbyte_register],2
	jb	lgdt_mem_store
	call	operand_32bit
      lgdt_mem_store:
	jmp	instruction_ready
lar_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	call	take_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	al,al
	xchg	al,[operand_size]
	call	operand_autodetect
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	lar_reg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	lar_reg_mem
	cmp	al,2
	jne	invalid_operand_size
      lar_reg_mem:
	jmp	instruction_ready
      lar_reg_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ah,2
	jne	invalid_operand_size
	mov	bl,al
	jmp	nomem_instruction_ready
invlpg_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],1
	mov	[postbyte_register],7
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	jmp	instruction_ready
swapgs_instruction:
	cmp	[code_type],64
	jne	illegal_instruction
rdtscp_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],1
	mov	[postbyte_register],7
	mov	bl,al
	jmp	nomem_instruction_ready

basic_486_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	basic_486_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	push	edx ebx ecx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	[postbyte_register],al
	pop	ecx ebx edx
	mov	al,ah
	cmp	al,1
	je	basic_486_mem_reg_8bit
	call	operand_autodetect
	inc	[extended_code]
      basic_486_mem_reg_8bit:
	jmp	instruction_ready
      basic_486_reg:
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	bl,[postbyte_register]
	mov	[postbyte_register],al
	mov	al,ah
	cmp	al,1
	je	basic_486_reg_reg_8bit
	call	operand_autodetect
	inc	[extended_code]
      basic_486_reg_reg_8bit:
	jmp	nomem_instruction_ready
bswap_instruction:
	call	take_register
	test	al,1000b
	jz	bswap_reg_code_ok
	or	[rex_prefix],41h
	and	al,111b
      bswap_reg_code_ok:
	add	al,0C8h
	mov	[extended_code],al
	mov	[base_code],0Fh
	cmp	ah,8
	je	bswap_reg64
	cmp	ah,4
	jne	invalid_operand_size
	call	operand_32bit
	call	store_classic_instruction_code
	jmp	instruction_assembled
      bswap_reg64:
	call	operand_64bit
	call	store_classic_instruction_code
	jmp	instruction_assembled
cmpxchgx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0C7h
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	ah,1
	xchg	[postbyte_register],ah
	mov	al,[operand_size]
	or	al,al
	jz	cmpxchgx_size_ok
	cmp	al,ah
	jne	invalid_operand_size
      cmpxchgx_size_ok:
	cmp	ah,16
	jne	cmpxchgx_store
	call	operand_64bit
      cmpxchgx_store:
	jmp	instruction_ready
nop_instruction:
	mov	ah,[esi]
	cmp	ah,10h
	je	extended_nop
	cmp	ah,11h
	je	extended_nop
	cmp	ah,'['
	je	extended_nop
	stos	byte [edi]
	jmp	instruction_assembled
      extended_nop:
	mov	[base_code],0Fh
	mov	[extended_code],1Fh
	mov	[postbyte_register],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	extended_nop_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	extended_nop_store
	call	operand_autodetect
      extended_nop_store:
	jmp	instruction_ready
      extended_nop_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,ah
	call	operand_autodetect
	jmp	nomem_instruction_ready

basic_fpu_instruction:
	mov	[postbyte_register],al
	mov	[base_code],0D8h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	basic_fpu_streg
	cmp	al,'['
	je	basic_fpu_mem
	dec	esi
	mov	ah,[postbyte_register]
	cmp	ah,2
	jb	invalid_operand
	cmp	ah,3
	ja	invalid_operand
	mov	bl,1
	jmp	nomem_instruction_ready
      basic_fpu_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,4
	je	basic_fpu_mem_32bit
	cmp	al,8
	je	basic_fpu_mem_64bit
	or	al,al
	jnz	invalid_operand_size
	call	recoverable_unknown_size
      basic_fpu_mem_32bit:
	jmp	instruction_ready
      basic_fpu_mem_64bit:
	mov	[base_code],0DCh
	jmp	instruction_ready
      basic_fpu_streg:
	lods	byte [esi]
	call	convert_fpu_register
	mov	bl,al
	mov	ah,[postbyte_register]
	cmp	ah,2
	je	basic_fpu_single_streg
	cmp	ah,3
	je	basic_fpu_single_streg
	or	al,al
	jz	basic_fpu_st0
	test	ah,110b
	jz	basic_fpu_streg_st0
	xor	[postbyte_register],1
      basic_fpu_streg_st0:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_fpu_register
	or	al,al
	jnz	invalid_operand
	mov	[base_code],0DCh
	jmp	nomem_instruction_ready
      basic_fpu_st0:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_fpu_register
	mov	bl,al
      basic_fpu_single_streg:
	mov	[base_code],0D8h
	jmp	nomem_instruction_ready
simple_fpu_instruction:
	mov	ah,al
	or	ah,11000000b
	mov	al,0D9h
	stos	word [edi]
	jmp	instruction_assembled
fi_instruction:
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	fi_mem_16bit
	cmp	al,4
	je	fi_mem_32bit
	or	al,al
	jnz	invalid_operand_size
	call	recoverable_unknown_size
      fi_mem_32bit:
	mov	[base_code],0DAh
	jmp	instruction_ready
      fi_mem_16bit:
	mov	[base_code],0DEh
	jmp	instruction_ready
fld_instruction:
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	fld_streg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,4
	je	fld_mem_32bit
	cmp	al,8
	je	fld_mem_64bit
	cmp	al,10
	je	fld_mem_80bit
	or	al,al
	jnz	invalid_operand_size
	call	recoverable_unknown_size
      fld_mem_32bit:
	mov	[base_code],0D9h
	jmp	instruction_ready
      fld_mem_64bit:
	mov	[base_code],0DDh
	jmp	instruction_ready
      fld_mem_80bit:
	mov	al,[postbyte_register]
	cmp	al,0
	je	fld_mem_80bit_store
	dec	[postbyte_register]
	cmp	al,3
	je	fld_mem_80bit_store
	jmp	invalid_operand_size
      fld_mem_80bit_store:
	add	[postbyte_register],5
	mov	[base_code],0DBh
	jmp	instruction_ready
      fld_streg:
	lods	byte [esi]
	call	convert_fpu_register
	mov	bl,al
	cmp	[postbyte_register],2
	jae	fst_streg
	mov	[base_code],0D9h
	jmp	nomem_instruction_ready
      fst_streg:
	mov	[base_code],0DDh
	jmp	nomem_instruction_ready
fild_instruction:
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	fild_mem_16bit
	cmp	al,4
	je	fild_mem_32bit
	cmp	al,8
	je	fild_mem_64bit
	or	al,al
	jnz	invalid_operand_size
	call	recoverable_unknown_size
      fild_mem_32bit:
	mov	[base_code],0DBh
	jmp	instruction_ready
      fild_mem_16bit:
	mov	[base_code],0DFh
	jmp	instruction_ready
      fild_mem_64bit:
	mov	al,[postbyte_register]
	cmp	al,1
	je	fisttp_64bit_store
	jb	fild_mem_64bit_store
	dec	[postbyte_register]
	cmp	al,3
	je	fild_mem_64bit_store
	jmp	invalid_operand_size
      fild_mem_64bit_store:
	add	[postbyte_register],5
	mov	[base_code],0DFh
	jmp	instruction_ready
      fisttp_64bit_store:
	mov	[base_code],0DDh
	jmp	instruction_ready
fbld_instruction:
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	fbld_mem_80bit
	cmp	al,10
	je	fbld_mem_80bit
	jmp	invalid_operand_size
      fbld_mem_80bit:
	mov	[base_code],0DFh
	jmp	instruction_ready
faddp_instruction:
	mov	[postbyte_register],al
	mov	[base_code],0DEh
	mov	edx,esi
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	faddp_streg
	mov	esi,edx
	mov	bl,1
	jmp	nomem_instruction_ready
      faddp_streg:
	lods	byte [esi]
	call	convert_fpu_register
	mov	bl,al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_fpu_register
	or	al,al
	jnz	invalid_operand
	jmp	nomem_instruction_ready
fcompp_instruction:
	mov	ax,0D9DEh
	stos	word [edi]
	jmp	instruction_assembled
fucompp_instruction:
	mov	ax,0E9DAh
	stos	word [edi]
	jmp	instruction_assembled
fxch_instruction:
	mov	dx,01D9h
	jmp	fpu_single_operand
ffreep_instruction:
	mov	dx,00DFh
	jmp	fpu_single_operand
ffree_instruction:
	mov	dl,0DDh
	mov	dh,al
      fpu_single_operand:
	mov	ebx,esi
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	fpu_streg
	or	dh,dh
	jz	invalid_operand
	mov	esi,ebx
	shl	dh,3
	or	dh,11000001b
	mov	ax,dx
	stos	word [edi]
	jmp	instruction_assembled
      fpu_streg:
	lods	byte [esi]
	call	convert_fpu_register
	shl	dh,3
	or	dh,al
	or	dh,11000000b
	mov	ax,dx
	stos	word [edi]
	jmp	instruction_assembled

fstenv_instruction:
	mov	byte [edi],9Bh
	inc	edi
fldenv_instruction:
	mov	[base_code],0D9h
	jmp	fpu_mem
fstenv_instruction_16bit:
	mov	byte [edi],9Bh
	inc	edi
fldenv_instruction_16bit:
	call	operand_16bit
	jmp	fldenv_instruction
fstenv_instruction_32bit:
	mov	byte [edi],9Bh
	inc	edi
fldenv_instruction_32bit:
	call	operand_32bit
	jmp	fldenv_instruction
fsave_instruction_32bit:
	mov	byte [edi],9Bh
	inc	edi
fnsave_instruction_32bit:
	call	operand_32bit
	jmp	fnsave_instruction
fsave_instruction_16bit:
	mov	byte [edi],9Bh
	inc	edi
fnsave_instruction_16bit:
	call	operand_16bit
	jmp	fnsave_instruction
fsave_instruction:
	mov	byte [edi],9Bh
	inc	edi
fnsave_instruction:
	mov	[base_code],0DDh
      fpu_mem:
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	jne	invalid_operand_size
	jmp	instruction_ready
fstcw_instruction:
	mov	byte [edi],9Bh
	inc	edi
fldcw_instruction:
	mov	[postbyte_register],al
	mov	[base_code],0D9h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	fldcw_mem_16bit
	cmp	al,2
	je	fldcw_mem_16bit
	jmp	invalid_operand_size
      fldcw_mem_16bit:
	jmp	instruction_ready
fstsw_instruction:
	mov	al,9Bh
	stos	byte [edi]
fnstsw_instruction:
	mov	[base_code],0DDh
	mov	[postbyte_register],7
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	fstsw_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	fstsw_mem_16bit
	cmp	al,2
	je	fstsw_mem_16bit
	jmp	invalid_operand_size
      fstsw_mem_16bit:
	jmp	instruction_ready
      fstsw_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ax,0200h
	jne	invalid_operand
	mov	ax,0E0DFh
	stos	word [edi]
	jmp	instruction_assembled
finit_instruction:
	mov	byte [edi],9Bh
	inc	edi
fninit_instruction:
	mov	ah,al
	mov	al,0DBh
	stos	word [edi]
	jmp	instruction_assembled
fcmov_instruction:
	mov	dh,0DAh
	jmp	fcomi_streg
fcomi_instruction:
	mov	dh,0DBh
	jmp	fcomi_streg
fcomip_instruction:
	mov	dh,0DFh
      fcomi_streg:
	mov	dl,al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_fpu_register
	mov	ah,al
	cmp	byte [esi],','
	je	fcomi_st0_streg
	add	ah,dl
	mov	al,dh
	stos	word [edi]
	jmp	instruction_assembled
      fcomi_st0_streg:
	or	ah,ah
	jnz	invalid_operand
	inc	esi
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_fpu_register
	mov	ah,al
	add	ah,dl
	mov	al,dh
	stos	word [edi]
	jmp	instruction_assembled

basic_mmx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
      mmx_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	call	make_mmx_prefix
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	mmx_mmreg_mmreg
	cmp	al,'['
	jne	invalid_operand
      mmx_mmreg_mem:
	call	get_address
	jmp	instruction_ready
      mmx_mmreg_mmreg:
	lods	byte [esi]
	call	convert_mmx_register
	mov	bl,al
	jmp	nomem_instruction_ready
mmx_bit_shift_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	call	make_mmx_prefix
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	mmx_mmreg_mmreg
	cmp	al,'('
	je	mmx_ps_mmreg_imm8
	cmp	al,'['
	je	mmx_mmreg_mem
	jmp	invalid_operand
      mmx_ps_mmreg_imm8:
	call	get_byte_value
	mov	byte [value],al
	test	[operand_size],not 1
	jnz	invalid_value
	mov	bl,[extended_code]
	mov	al,bl
	shr	bl,4
	and	al,1111b
	add	al,70h
	mov	[extended_code],al
	sub	bl,0Ch
	shl	bl,1
	xchg	bl,[postbyte_register]
	call	store_nomem_instruction
	mov	al,byte [value]
	stos	byte [edi]
	jmp	instruction_assembled
pmovmskb_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	call	take_register
	cmp	ah,4
	je	pmovmskb_reg_size_ok
	cmp	[code_type],64
	jne	invalid_operand_size
	cmp	ah,8
	jnz	invalid_operand_size
      pmovmskb_reg_size_ok:
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	mov	bl,al
	call	make_mmx_prefix
	cmp	[extended_code],0C5h
	je	mmx_nomem_imm8
	jmp	nomem_instruction_ready
      mmx_imm8:
	push	ebx ecx edx
	xor	cl,cl
	xchg	cl,[operand_size]
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	test	ah,not 1
	jnz	invalid_operand_size
	mov	[operand_size],cl
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	mov	byte [value],al
	pop	edx ecx ebx
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      mmx_nomem_imm8:
	call	store_nomem_instruction
	call	append_imm8
	jmp	instruction_assembled
      append_imm8:
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	test	ah,not 1
	jnz	invalid_operand_size
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	stosb
	ret
pinsrw_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	call	make_mmx_prefix
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	pinsrw_mmreg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	je	mmx_imm8
	cmp	[operand_size],2
	jne	invalid_operand_size
	jmp	mmx_imm8
      pinsrw_mmreg_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	bl,al
	jmp	mmx_nomem_imm8
pshufw_instruction:
	mov	[mmx_size],8
	mov	[opcode_prefix],al
	jmp	pshuf_instruction
pshufd_instruction:
	mov	[mmx_size],16
	mov	[opcode_prefix],al
      pshuf_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],70h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	pshuf_mmreg_mmreg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	jmp	mmx_imm8
      pshuf_mmreg_mmreg:
	lods	byte [esi]
	call	convert_mmx_register
	mov	bl,al
	jmp	mmx_nomem_imm8
movd_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],7Eh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	movd_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	test	[operand_size],not 4
	jnz	invalid_operand_size
	call	get_mmx_source_register
	jmp	instruction_ready
      movd_reg:
	lods	byte [esi]
	cmp	al,0B0h
	jae	movd_mmreg
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	bl,al
	call	get_mmx_source_register
	jmp	nomem_instruction_ready
      movd_mmreg:
	mov	[extended_code],6Eh
	call	convert_mmx_register
	mov	[postbyte_register],al
	call	make_mmx_prefix
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	movd_mmreg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	test	[operand_size],not 4
	jnz	invalid_operand_size
	jmp	instruction_ready
      movd_mmreg_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	bl,al
	jmp	nomem_instruction_ready
      get_mmx_source_register:
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	mov	[postbyte_register],al
      make_mmx_prefix:
	cmp	[operand_size],16
	jne	no_mmx_prefix
	mov	[operand_prefix],66h
      no_mmx_prefix:
	ret
movq_instruction:
	mov	[base_code],0Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	movq_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	test	[operand_size],not 8
	jnz	invalid_operand_size
	call	get_mmx_source_register
	mov	al,7Fh
	cmp	ah,8
	je	movq_mem_ready
	mov	al,0D6h
     movq_mem_ready:
	mov	[extended_code],al
	jmp	instruction_ready
     movq_reg:
	lods	byte [esi]
	cmp	al,0B0h
	jae	movq_mmreg
	call	convert_register
	cmp	ah,8
	jne	invalid_operand_size
	mov	bl,al
	mov	[extended_code],7Eh
	call	operand_64bit
	call	get_mmx_source_register
	jmp	nomem_instruction_ready
     movq_mmreg:
	call	convert_mmx_register
	mov	[postbyte_register],al
	mov	[extended_code],6Fh
	mov	[mmx_size],ah
	cmp	ah,16
	jne	movq_mmreg_
	mov	[extended_code],7Eh
	mov	[opcode_prefix],0F3h
      movq_mmreg_:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	movq_mmreg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	test	[operand_size],not 8
	jnz	invalid_operand_size
	jmp	instruction_ready
      movq_mmreg_reg:
	lods	byte [esi]
	cmp	al,0B0h
	jae	movq_mmreg_mmreg
	mov	[operand_size],0
	call	convert_register
	cmp	ah,8
	jne	invalid_operand_size
	mov	[extended_code],6Eh
	mov	[opcode_prefix],0
	mov	bl,al
	cmp	[mmx_size],16
	jne	movq_mmreg_reg_store
	mov	[opcode_prefix],66h
      movq_mmreg_reg_store:
	call	operand_64bit
	jmp	nomem_instruction_ready
      movq_mmreg_mmreg:
	call	convert_mmx_register
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	mov	bl,al
	jmp	nomem_instruction_ready
movdq_instruction:
	mov	[opcode_prefix],al
	mov	[base_code],0Fh
	mov	[extended_code],6Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	movdq_mmreg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	mov	[extended_code],7Fh
	jmp	instruction_ready
      movdq_mmreg:
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	movdq_mmreg_mmreg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	jmp	instruction_ready
      movdq_mmreg_mmreg:
	lods	byte [esi]
	call	convert_xmm_register
	mov	bl,al
	jmp	nomem_instruction_ready
lddqu_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	push	eax
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop	eax
	mov	[postbyte_register],al
	mov	[opcode_prefix],0F2h
	mov	[base_code],0Fh
	mov	[extended_code],0F0h
	jmp	instruction_ready

movdq2q_instruction:
	mov	[opcode_prefix],0F2h
	mov	[mmx_size],8
	jmp	movq2dq_
movq2dq_instruction:
	mov	[opcode_prefix],0F3h
	mov	[mmx_size],16
      movq2dq_:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	xor	[mmx_size],8+16
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	mov	bl,al
	mov	[base_code],0Fh
	mov	[extended_code],0D6h
	jmp	nomem_instruction_ready

sse_ps_instruction_imm8:
	mov	[immediate_size],1
sse_ps_instruction:
	mov	[mmx_size],16
	jmp	sse_instruction
sse_pd_instruction_imm8:
	mov	[immediate_size],1
sse_pd_instruction:
	mov	[mmx_size],16
	mov	[opcode_prefix],66h
	jmp	sse_instruction
sse_ss_instruction:
	mov	[mmx_size],4
	mov	[opcode_prefix],0F3h
	jmp	sse_instruction
sse_sd_instruction:
	mov	[mmx_size],8
	mov	[opcode_prefix],0F2h
	jmp	sse_instruction
cmp_pd_instruction:
	mov	[opcode_prefix],66h
cmp_ps_instruction:
	mov	[mmx_size],16
	mov	byte [value],al
	mov	al,0C2h
	jmp	sse_instruction
cmp_ss_instruction:
	mov	[mmx_size],4
	mov	[opcode_prefix],0F3h
	jmp	cmp_sx_instruction
cmpsd_instruction:
	mov	al,0A7h
	mov	ah,[esi]
	or	ah,ah
	jz	simple_instruction_32bit
	cmp	ah,0Fh
	je	simple_instruction_32bit
	mov	al,-1
cmp_sd_instruction:
	mov	[mmx_size],8
	mov	[opcode_prefix],0F2h
      cmp_sx_instruction:
	mov	byte [value],al
	mov	al,0C2h
	jmp	sse_instruction
comiss_instruction:
	mov	[mmx_size],4
	jmp	sse_instruction
comisd_instruction:
	mov	[mmx_size],8
	mov	[opcode_prefix],66h
	jmp	sse_instruction
cvtdq2pd_instruction:
	mov	[opcode_prefix],0F3h
cvtps2pd_instruction:
	mov	[mmx_size],8
	jmp	sse_instruction
cvtpd2dq_instruction:
	mov	[mmx_size],16
	mov	[opcode_prefix],0F2h
	jmp	sse_instruction
movshdup_instruction:
	mov	[mmx_size],16
	mov	[opcode_prefix],0F3h
sse_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
      sse_xmmreg:
	lods	byte [esi]
	call	convert_xmm_register
      sse_reg:
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	sse_xmmreg_xmmreg
      sse_reg_mem:
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	je	sse_mem_size_ok
	mov	al,[mmx_size]
	cmp	[operand_size],al
	jne	invalid_operand_size
      sse_mem_size_ok:
	mov	al,[extended_code]
	mov	ah,[supplemental_code]
	cmp	al,0C2h
	je	sse_cmp_mem_ok
	cmp	ax,443Ah
	je	sse_cmp_mem_ok
	cmp	[immediate_size],1
	je	mmx_imm8
	cmp	[immediate_size],-1
	jne	sse_ok
	call	take_additional_xmm0
	mov	[immediate_size],0
      sse_ok:
	jmp	instruction_ready
      sse_cmp_mem_ok:
	cmp	byte [value],-1
	je	mmx_imm8
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      sse_xmmreg_xmmreg:
	cmp	[operand_prefix],66h
	jne	sse_xmmreg_xmmreg_ok
	cmp	[extended_code],12h
	je	invalid_operand
	cmp	[extended_code],16h
	je	invalid_operand
      sse_xmmreg_xmmreg_ok:
	lods	byte [esi]
	call	convert_xmm_register
	mov	bl,al
	mov	al,[extended_code]
	mov	ah,[supplemental_code]
	cmp	al,0C2h
	je	sse_cmp_nomem_ok
	cmp	ax,443Ah
	je	sse_cmp_nomem_ok
	cmp	[immediate_size],1
	je	mmx_nomem_imm8
	cmp	[immediate_size],-1
	jne	sse_nomem_ok
	call	take_additional_xmm0
	mov	[immediate_size],0
      sse_nomem_ok:
	jmp	nomem_instruction_ready
      sse_cmp_nomem_ok:
	cmp	byte [value],-1
	je	mmx_nomem_imm8
	call	store_nomem_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      take_additional_xmm0:
	cmp	byte [esi],','
	jne	additional_xmm0_ok
	inc	esi
	lods	byte [esi]
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	test	al,al
	jnz	invalid_operand
      additional_xmm0_ok:
	ret

pslldq_instruction:
	mov	[postbyte_register],al
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],73h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	bl,al
	jmp	mmx_nomem_imm8
movpd_instruction:
	mov	[opcode_prefix],66h
movps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],16
	jmp	sse_mov_instruction
movss_instruction:
	mov	[mmx_size],4
	mov	[opcode_prefix],0F3h
	jmp	sse_movs
movsd_instruction:
	mov	al,0A5h
	mov	ah,[esi]
	or	ah,ah
	jz	simple_instruction_32bit
	cmp	ah,0Fh
	je	simple_instruction_32bit
	mov	[mmx_size],8
	mov	[opcode_prefix],0F2h
      sse_movs:
	mov	[base_code],0Fh
	mov	[extended_code],10h
	jmp	sse_mov_instruction
sse_mov_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	sse_xmmreg
      sse_mem:
	cmp	al,'['
	jne	invalid_operand
	inc	[extended_code]
	call	get_address
	cmp	[operand_size],0
	je	sse_mem_xmmreg
	mov	al,[mmx_size]
	cmp	[operand_size],al
	jne	invalid_operand_size
	mov	[operand_size],0
      sse_mem_xmmreg:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	jmp	instruction_ready
movlpd_instruction:
	mov	[opcode_prefix],66h
movlps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],8
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	sse_mem
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	jmp	sse_reg_mem
movhlps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	sse_xmmreg_xmmreg_ok
	jmp	invalid_operand
maskmovq_instruction:
	mov	cl,8
	jmp	maskmov_instruction
maskmovdqu_instruction:
	mov	cl,16
	mov	[opcode_prefix],66h
      maskmov_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0F7h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	cmp	ah,cl
	jne	invalid_operand_size
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	mov	bl,al
	jmp	nomem_instruction_ready
movmskpd_instruction:
	mov	[opcode_prefix],66h
movmskps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],50h
	call	take_register
	mov	[postbyte_register],al
	cmp	ah,4
	je	movmskps_reg_ok
	cmp	ah,8
	jne	invalid_operand_size
	cmp	[code_type],64
	jne	invalid_operand
      movmskps_reg_ok:
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	sse_xmmreg_xmmreg_ok
	jmp	invalid_operand

cvtpi2pd_instruction:
	mov	[opcode_prefix],66h
cvtpi2ps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	cvtpi_xmmreg_xmmreg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	je	cvtpi_size_ok
	cmp	[operand_size],8
	jne	invalid_operand_size
      cvtpi_size_ok:
	jmp	instruction_ready
      cvtpi_xmmreg_xmmreg:
	lods	byte [esi]
	call	convert_mmx_register
	cmp	ah,8
	jne	invalid_operand_size
	mov	bl,al
	jmp	nomem_instruction_ready
cvtsi2ss_instruction:
	mov	[opcode_prefix],0F3h
	jmp	cvtsi_instruction
cvtsi2sd_instruction:
	mov	[opcode_prefix],0F2h
      cvtsi_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
      cvtsi_xmmreg:
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	cvtsi_xmmreg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	je	cvtsi_size_ok
	cmp	[operand_size],4
	je	cvtsi_size_ok
	cmp	[operand_size],8
	jne	invalid_operand_size
	call	operand_64bit
      cvtsi_size_ok:
	jmp	instruction_ready
      cvtsi_xmmreg_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ah,4
	je	cvtsi_xmmreg_reg_store
	cmp	ah,8
	jne	invalid_operand_size
	call	operand_64bit
      cvtsi_xmmreg_reg_store:
	mov	bl,al
	jmp	nomem_instruction_ready
cvtps2pi_instruction:
	mov	[mmx_size],8
	jmp	cvtpd_instruction
cvtpd2pi_instruction:
	mov	[opcode_prefix],66h
	mov	[mmx_size],16
      cvtpd_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	cmp	ah,8
	jne	invalid_operand_size
	mov	[operand_size],0
	jmp	sse_reg
cvtss2si_instruction:
	mov	[opcode_prefix],0F3h
	mov	[mmx_size],4
	jmp	cvt2si_instruction
cvtsd2si_instruction:
	mov	[opcode_prefix],0F2h
	mov	[mmx_size],8
      cvt2si_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	call	take_register
	mov	[operand_size],0
	cmp	ah,4
	je	sse_reg
	cmp	ah,8
	jne	invalid_operand_size
	call	operand_64bit
	jmp	sse_reg

ssse3_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],38h
	mov	[supplemental_code],al
	jmp	mmx_instruction
palignr_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],3Ah
	mov	[supplemental_code],0Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	call	make_mmx_prefix
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	palignr_mmreg_mmreg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	jmp	mmx_imm8
      palignr_mmreg_mmreg:
	lods	byte [esi]
	call	convert_mmx_register
	mov	bl,al
	jmp	mmx_nomem_imm8
amd3dnow_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0Fh
	mov	byte [value],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	cmp	ah,8
	jne	invalid_operand_size
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	amd3dnow_mmreg_mmreg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      amd3dnow_mmreg_mmreg:
	lods	byte [esi]
	call	convert_mmx_register
	cmp	ah,8
	jne	invalid_operand_size
	mov	bl,al
	call	store_nomem_instruction
	mov	al,byte [value]
	stos	byte [edi]
	jmp	instruction_assembled

sse4_instruction_38_xmm0:
	mov	[immediate_size],-1
	jmp	sse4_instruction_38
sse4_instruction_66_38_xmm0:
	mov	[immediate_size],-1
sse4_instruction_66_38:
	mov	[opcode_prefix],66h
sse4_instruction_38:
	mov	[mmx_size],16
	mov	[supplemental_code],al
	mov	al,38h
	jmp	sse_instruction
sse4_ss_instruction_66_3a_imm8:
	mov	[immediate_size],1
	mov	cl,4
	jmp	sse4_instruction_66_3a_setup
sse4_sd_instruction_66_3a_imm8:
	mov	[immediate_size],1
	mov	cl,8
	jmp	sse4_instruction_66_3a_setup
sse4_instruction_66_3a_imm8:
	mov	[immediate_size],1
	mov	cl,16
      sse4_instruction_66_3a_setup:
	mov	[opcode_prefix],66h
      sse4_instruction_3a_setup:
	mov	[supplemental_code],al
	mov	al,3Ah
	mov	[mmx_size],cl
	jmp	sse_instruction
sse4_instruction_3a_imm8:
	mov	[immediate_size],1
	mov	cl,16
	jmp	sse4_instruction_3a_setup
pclmulqdq_instruction:
	mov	byte [value],al
	mov	al,44h
	mov	cl,16
	jmp	sse4_instruction_66_3a_setup
extractps_instruction:
	call	setup_66_0f_3a
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	extractps_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],4
	je	extractps_size_ok
	cmp	[operand_size],0
	jne	invalid_operand_size
      extractps_size_ok:
	push	edx ebx ecx
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	pop	ecx ebx edx
	jmp	mmx_imm8
      extractps_reg:
	lods	byte [esi]
	call	convert_register
	push	eax
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	pop	ebx
	mov	al,bh
	cmp	al,4
	je	mmx_nomem_imm8
	cmp	al,8
	jne	invalid_operand_size
	call	operand_64bit
	jmp	mmx_nomem_imm8
      setup_66_0f_3a:
	mov	[extended_code],3Ah
	mov	[supplemental_code],al
	mov	[base_code],0Fh
	mov	[opcode_prefix],66h
	ret
insertps_instruction:
	call	setup_66_0f_3a
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	insertps_xmmreg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],4
	je	insertps_size_ok
	cmp	[operand_size],0
	jne	invalid_operand_size
      insertps_size_ok:
	jmp	mmx_imm8
      insertps_xmmreg_reg:
	lods	byte [esi]
	call	convert_mmx_register
	mov	bl,al
	jmp	mmx_nomem_imm8
pextrq_instruction:
	mov	[mmx_size],8
	jmp	pextr_instruction
pextrd_instruction:
	mov	[mmx_size],4
	jmp	pextr_instruction
pextrw_instruction:
	mov	[mmx_size],2
	jmp	pextr_instruction
pextrb_instruction:
	mov	[mmx_size],1
      pextr_instruction:
	call	setup_66_0f_3a
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	pextr_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[mmx_size]
	cmp	al,[operand_size]
	je	pextr_size_ok
	cmp	[operand_size],0
	jne	invalid_operand_size
      pextr_size_ok:
	cmp	al,8
	jne	pextr_prefix_ok
	call	operand_64bit
      pextr_prefix_ok:
	push	edx ebx ecx
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	pop	ecx ebx edx
	jmp	mmx_imm8
      pextr_reg:
	lods	byte [esi]
	call	convert_register
	cmp	[mmx_size],4
	ja	pextrq_reg
	cmp	ah,4
	je	pextr_reg_size_ok
	cmp	[code_type],64
	jne	pextr_invalid_size
	cmp	ah,8
	je	pextr_reg_size_ok
      pextr_invalid_size:
	jmp	invalid_operand_size
      pextrq_reg:
	cmp	ah,8
	jne	pextr_invalid_size
	call	operand_64bit
      pextr_reg_size_ok:
	mov	[operand_size],0
	push	eax
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	mov	ebx,eax
	pop	eax
	mov	[postbyte_register],al
	mov	al,ah
	cmp	[mmx_size],2
	jne	pextr_reg_store
	mov	[opcode_prefix],0
	mov	[extended_code],0C5h
	call	make_mmx_prefix
	jmp	mmx_nomem_imm8
      pextr_reg_store:
	cmp	bh,16
	jne	invalid_operand_size
	xchg	bl,[postbyte_register]
	call	operand_autodetect
	jmp	mmx_nomem_imm8
pinsrb_instruction:
	mov	[mmx_size],1
	jmp	pinsr_instruction
pinsrd_instruction:
	mov	[mmx_size],4
	jmp	pinsr_instruction
pinsrq_instruction:
	mov	[mmx_size],8
	call	operand_64bit
      pinsr_instruction:
	call	setup_66_0f_3a
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
      pinsr_xmmreg:
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	pinsr_xmmreg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	je	mmx_imm8
	mov	al,[mmx_size]
	cmp	al,[operand_size]
	je	mmx_imm8
	jmp	invalid_operand_size
      pinsr_xmmreg_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	cmp	[mmx_size],8
	je	pinsrq_xmmreg_reg
	cmp	ah,4
	je	mmx_nomem_imm8
	jmp	invalid_operand_size
      pinsrq_xmmreg_reg:
	cmp	ah,8
	je	mmx_nomem_imm8
	jmp	invalid_operand_size
pmovsxbw_instruction:
	mov	[mmx_size],8
	jmp	pmovsx_instruction
pmovsxbd_instruction:
	mov	[mmx_size],4
	jmp	pmovsx_instruction
pmovsxbq_instruction:
	mov	[mmx_size],2
	jmp	pmovsx_instruction
pmovsxwd_instruction:
	mov	[mmx_size],8
	jmp	pmovsx_instruction
pmovsxwq_instruction:
	mov	[mmx_size],4
	jmp	pmovsx_instruction
pmovsxdq_instruction:
	mov	[mmx_size],8
      pmovsx_instruction:
	call	setup_66_0f_38
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	pmovsx_xmmreg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	je	instruction_ready
	mov	al,[mmx_size]
	cmp	al,[operand_size]
	jne	invalid_operand_size
	jmp	instruction_ready
      pmovsx_xmmreg_reg:
	lods	byte [esi]
	call	convert_xmm_register
	mov	bl,al
	jmp	nomem_instruction_ready
      setup_66_0f_38:
	mov	[extended_code],38h
	mov	[supplemental_code],al
	mov	[base_code],0Fh
	mov	[opcode_prefix],66h
	ret

fxsave_instruction_64bit:
	call	operand_64bit
fxsave_instruction:
	mov	[extended_code],0AEh
	mov	[base_code],0Fh
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	ah,[operand_size]
	or	ah,ah
	jz	fxsave_size_ok
	mov	al,[postbyte_register]
	cmp	al,111b
	je	clflush_size_check
	cmp	al,10b
	jb	invalid_operand_size
	cmp	al,11b
	ja	invalid_operand_size
	cmp	ah,4
	jne	invalid_operand_size
	jmp	fxsave_size_ok
      clflush_size_check:
	cmp	ah,1
	jne	invalid_operand_size
      fxsave_size_ok:
	jmp	instruction_ready
prefetch_instruction:
	mov	[extended_code],18h
      prefetch_mem_8bit:
	mov	[base_code],0Fh
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	or	ah,ah
	jz	prefetch_size_ok
	cmp	ah,1
	jne	invalid_operand_size
      prefetch_size_ok:
	call	get_address
	jmp	instruction_ready
amd_prefetch_instruction:
	mov	[extended_code],0Dh
	jmp	prefetch_mem_8bit
clflushopt_instruction:
	mov	[extended_code],0AEh
	mov	[opcode_prefix],66h
	jmp	prefetch_mem_8bit
pcommit_instruction:
	mov	byte [edi],66h
	inc	edi
fence_instruction:
	mov	bl,al
	mov	ax,0AE0Fh
	stos	word [edi]
	mov	al,bl
	stos	byte [edi]
	jmp	instruction_assembled
pause_instruction:
	mov	ax,90F3h
	stos	word [edi]
	jmp	instruction_assembled
movntq_instruction:
	mov	[mmx_size],8
	jmp	movnt_instruction
movntpd_instruction:
	mov	[opcode_prefix],66h
movntps_instruction:
	mov	[mmx_size],16
      movnt_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_mmx_register
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	mov	[postbyte_register],al
	jmp	instruction_ready

movntsd_instruction:
	mov	[opcode_prefix],0F2h
	mov	[mmx_size],8
	jmp	movnts_instruction
movntss_instruction:
	mov	[opcode_prefix],0F3h
	mov	[mmx_size],4
      movnts_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,[mmx_size]
	je	movnts_size_ok
	test	al,al
	jnz	invalid_operand_size
      movnts_size_ok:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	jmp	instruction_ready

movnti_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	cmp	ah,4
	je	movnti_store
	cmp	ah,8
	jne	invalid_operand_size
	call	operand_64bit
      movnti_store:
	mov	[postbyte_register],al
	jmp	instruction_ready
monitor_instruction:
	mov	[postbyte_register],al
	cmp	byte [esi],0
	je	monitor_instruction_store
	cmp	byte [esi],0Fh
	je	monitor_instruction_store
	call	take_register
	cmp	ax,0400h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	cmp	ax,0401h
	jne	invalid_operand
	cmp	[postbyte_register],0C8h
	jne	monitor_instruction_store
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	cmp	ax,0402h
	jne	invalid_operand
      monitor_instruction_store:
	mov	ax,010Fh
	stos	word [edi]
	mov	al,[postbyte_register]
	stos	byte [edi]
	jmp	instruction_assembled
movntdqa_instruction:
	call	setup_66_0f_38
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	jmp	instruction_ready

extrq_instruction:
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],78h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	extrq_xmmreg_xmmreg
	test	ah,not 1
	jnz	invalid_operand_size
	cmp	al,'('
	jne	invalid_operand
	xor	bl,bl
	xchg	bl,[postbyte_register]
	call	store_nomem_instruction
	call	get_byte_value
	stosb
	call	append_imm8
	jmp	instruction_assembled
      extrq_xmmreg_xmmreg:
	inc	[extended_code]
	lods	byte [esi]
	call	convert_xmm_register
	mov	bl,al
	jmp	nomem_instruction_ready
insertq_instruction:
	mov	[opcode_prefix],0F2h
	mov	[base_code],0Fh
	mov	[extended_code],78h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	bl,al
	cmp	byte [esi],','
	je	insertq_with_imm
	inc	[extended_code]
	jmp	nomem_instruction_ready
      insertq_with_imm:
	call	store_nomem_instruction
	call	append_imm8
	call	append_imm8
	jmp	instruction_assembled

crc32_instruction:
	mov	[opcode_prefix],0F2h
	mov	[base_code],0Fh
	mov	[extended_code],38h
	mov	[supplemental_code],0F0h
	call	take_register
	mov	[postbyte_register],al
	cmp	ah,8
	je	crc32_reg64
	cmp	ah,4
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	crc32_reg32_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	test	al,al
	jz	crc32_unknown_size
	cmp	al,1
	je	crc32_reg32_mem_store
	cmp	al,4
	ja	invalid_operand_size
	inc	[supplemental_code]
	call	operand_autodetect
      crc32_reg32_mem_store:
	jmp	instruction_ready
      crc32_unknown_size:
	call	recoverable_unknown_size
	jmp	crc32_reg32_mem_store
      crc32_reg32_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,ah
	cmp	al,1
	je	crc32_reg32_reg_store
	cmp	al,4
	ja	invalid_operand_size
	inc	[supplemental_code]
	call	operand_autodetect
      crc32_reg32_reg_store:
	jmp	nomem_instruction_ready
      crc32_reg64:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	call	operand_64bit
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	crc32_reg64_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	ah,[operand_size]
	mov	al,8
	test	ah,ah
	jz	crc32_unknown_size
	cmp	ah,1
	je	crc32_reg32_mem_store
	cmp	ah,al
	jne	invalid_operand_size
	inc	[supplemental_code]
	jmp	crc32_reg32_mem_store
      crc32_reg64_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,8
	cmp	ah,1
	je	crc32_reg32_reg_store
	cmp	ah,al
	jne	invalid_operand_size
	inc	[supplemental_code]
	jmp	crc32_reg32_reg_store
popcnt_instruction:
	mov	[opcode_prefix],0F3h
	jmp	bs_instruction
movbe_instruction:
	mov	[supplemental_code],al
	mov	[extended_code],38h
	mov	[base_code],0Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	movbe_mem
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	mov	al,[operand_size]
	call	operand_autodetect
	jmp	instruction_ready
      movbe_mem:
	inc	[supplemental_code]
	call	get_address
	push	edx ebx ecx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	[postbyte_register],al
	pop	ecx ebx edx
	mov	al,[operand_size]
	call	operand_autodetect
	jmp	instruction_ready
adx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],38h
	mov	[supplemental_code],0F6h
	mov	[operand_prefix],al
	call	get_reg_mem
	jc	adx_reg_reg
	mov	al,[operand_size]
	cmp	al,4
	je	instruction_ready
	cmp	al,8
	jne	invalid_operand_size
	call	operand_64bit
	jmp	instruction_ready
      adx_reg_reg:
	cmp	ah,4
	je	nomem_instruction_ready
	cmp	ah,8
	jne	invalid_operand_size
	call	operand_64bit
	jmp	nomem_instruction_ready

simple_vmx_instruction:
	mov	ah,al
	mov	al,0Fh
	stos	byte [edi]
	mov	al,1
	stos	word [edi]
	jmp	instruction_assembled
vmclear_instruction:
	mov	[opcode_prefix],66h
	jmp	vmx_instruction
vmxon_instruction:
	mov	[opcode_prefix],0F3h
vmx_instruction:
	mov	[postbyte_register],al
	mov	[extended_code],0C7h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	vmx_size_ok
	cmp	al,8
	jne	invalid_operand_size
      vmx_size_ok:
	mov	[base_code],0Fh
	jmp	instruction_ready
vmread_instruction:
	mov	[extended_code],78h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	vmread_nomem
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	[postbyte_register],al
	call	vmread_check_size
	jmp	vmx_size_ok
      vmread_nomem:
	lods	byte [esi]
	call	convert_register
	push	eax
	call	vmread_check_size
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	mov	[postbyte_register],al
	call	vmread_check_size
	pop	ebx
	mov	[base_code],0Fh
	jmp	nomem_instruction_ready
      vmread_check_size:
	cmp	[code_type],64
	je	vmread_long
	cmp	[operand_size],4
	jne	invalid_operand_size
	ret
      vmread_long:
	cmp	[operand_size],8
	jne	invalid_operand_size
	ret
vmwrite_instruction:
	mov	[extended_code],79h
	call	take_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	vmwrite_nomem
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	call	vmread_check_size
	jmp	vmx_size_ok
      vmwrite_nomem:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	[base_code],0Fh
	jmp	nomem_instruction_ready
vmx_inv_instruction:
	call	setup_66_0f_38
	call	take_register
	mov	[postbyte_register],al
	call	vmread_check_size
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	vmx_size_ok
	cmp	al,16
	jne	invalid_operand_size
	jmp	vmx_size_ok
simple_svm_instruction:
	push	eax
	mov	[base_code],0Fh
	mov	[extended_code],1
	call	take_register
	or	al,al
	jnz	invalid_operand
      simple_svm_detect_size:
	cmp	ah,2
	je	simple_svm_16bit
	cmp	ah,4
	je	simple_svm_32bit
	cmp	[code_type],64
	jne	invalid_operand_size
	jmp	simple_svm_store
      simple_svm_16bit:
	cmp	[code_type],16
	je	simple_svm_store
	cmp	[code_type],64
	je	invalid_operand_size
	jmp	prefixed_svm_store
      simple_svm_32bit:
	cmp	[code_type],32
	je	simple_svm_store
      prefixed_svm_store:
	mov	al,67h
	stos	byte [edi]
      simple_svm_store:
	call	store_classic_instruction_code
	pop	eax
	stos	byte [edi]
	jmp	instruction_assembled
skinit_instruction:
	call	take_register
	cmp	ax,0400h
	jne	invalid_operand
	mov	al,0DEh
	jmp	simple_vmx_instruction
invlpga_instruction:
	push	eax
	mov	[base_code],0Fh
	mov	[extended_code],1
	call	take_register
	or	al,al
	jnz	invalid_operand
	mov	bl,ah
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_register
	cmp	ax,0401h
	jne	invalid_operand
	mov	ah,bl
	jmp	simple_svm_detect_size

rdrand_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0C7h
	mov	[postbyte_register],al
	call	take_register
	mov	bl,al
	mov	al,ah
	call	operand_autodetect
	jmp	nomem_instruction_ready
rdfsbase_instruction:
	cmp	[code_type],64
	jne	illegal_instruction
	mov	[opcode_prefix],0F3h
	mov	[base_code],0Fh
	mov	[extended_code],0AEh
	mov	[postbyte_register],al
	call	take_register
	mov	bl,al
	mov	al,ah
	cmp	ah,2
	je	invalid_operand_size
	call	operand_autodetect
	jmp	nomem_instruction_ready

xabort_instruction:
	lods	byte [esi]
	call	get_size_operator
	cmp	ah,1
	ja	invalid_operand_size
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	mov	dl,al
	mov	ax,0F8C6h
	stos	word [edi]
	mov	al,dl
	stos	byte [edi]
	jmp	instruction_assembled
xbegin_instruction:
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_operand
	mov	al,[code_type]
	cmp	al,64
	je	xbegin_64bit
	cmp	al,32
	je	xbegin_32bit
      xbegin_16bit:
	call	get_address_word_value
	add	edi,4
	mov	ebp,[addressing_space]
	call	calculate_relative_offset
	sub	edi,4
	shl	eax,16
	mov	ax,0F8C7h
	stos	dword [edi]
	jmp	instruction_assembled
      xbegin_32bit:
	call	get_address_dword_value
	jmp	xbegin_address_ok
      xbegin_64bit:
	call	get_address_qword_value
      xbegin_address_ok:
	add	edi,5
	mov	ebp,[addressing_space]
	call	calculate_relative_offset
	sub	edi,5
	mov	edx,eax
	cwde
	cmp	eax,edx
	jne	xbegin_rel32
	mov	al,66h
	stos	byte [edi]
	mov	eax,edx
	shl	eax,16
	mov	ax,0F8C7h
	stos	dword [edi]
	jmp	instruction_assembled
      xbegin_rel32:
	sub	edx,1
	jno	xbegin_rel32_ok
	cmp	[code_type],64
	je	jump_out_of_range
      xbegin_rel32_ok:
	mov	ax,0F8C7h
	stos	word [edi]
	mov	eax,edx
	stos	dword [edi]
	jmp	instruction_assembled

bndcl_instruction:
	mov	ah,0F3h
	jmp	bndc_instruction
bndcu_instruction:
	mov	ah,0F2h
      bndc_instruction:
	mov	[opcode_prefix],ah
	mov	[base_code],0Fh
	mov	[extended_code],al
	call	take_bnd_register
	mov	[postbyte_register],al
	call	get_bnd_size
	mov	[operand_size],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	bndc_mem
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	jmp	nomem_instruction_ready
      bndc_mem:
	call	get_address_of_required_size
	jmp	instruction_ready
bndmov_instruction:
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],al
	call	get_bnd_size
	shl	al,1
	mov	[operand_size],al
	lods	byte [esi]
	cmp	al,14h
	je	bndmov_reg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	inc	[extended_code]
	call	get_address_of_required_size
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_bnd_register
	mov	[postbyte_register],al
	jmp	instruction_ready
       bndmov_reg:
	lods	byte [esi]
	call	convert_bnd_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,14h
	je	bndmov_reg_reg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address_of_required_size
	jmp	instruction_ready
      bndmov_reg_reg:
	lods	byte [esi]
	call	convert_bnd_register
	mov	bl,al
	jmp	nomem_instruction_ready
    take_bnd_register:
	lods	byte [esi]
	cmp	al,14h
	jne	invalid_operand
	lods	byte [esi]
    convert_bnd_register:
	mov	ah,al
	shr	ah,4
	cmp	ah,6
	jne	invalid_operand
	and	al,1111b
	ret
bndmk_instruction:
	mov	[opcode_prefix],0F3h
	mov	[base_code],0Fh
	mov	[extended_code],al
	call	take_bnd_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_bnd_size
	call	get_address_prefixes
	call	get_address_component
	cmp	byte [esi-1],']'
	je	bndmk_ready
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_operand
	or	dl,bl
	or	dl,[address_sign]
	or	edx,[address_high]
	jnz	invalid_address
	mov	[address_register],bh
	call	get_address_component
	lods	byte [esi]
	cmp	al,']'
	jne	invalid_operand
	or	bh,bh
	jz	bndmk_selected_base
	cmp	bl,bh
	je	bndmk_to_index
	or	bl,bl
	jnz	invalid_address
	mov	bl,bh
      bndmk_to_index:
	inc	cl
      bndmk_selected_base:
	mov	bh,[address_register]
      bndmk_ready:
	or	bx,bx
	jz	instruction_ready
	cmp	[address_size_declared],0
	jne	instruction_ready
	and	ch,not 0Fh
	jmp	instruction_ready
    get_bnd_size:
	mov	al,4
	cmp	[code_type],64
	jne	bnd_size_ok
	add	al,4
      bnd_size_ok:
	mov	[address_size],al
	ret
    get_address_component:
	mov	[free_address_range],0
	call	calculate_address
	mov	[address_high],edx
	mov	edx,eax
	or	bx,bx
	jz	address_component_ok
	mov	al,bl
	or	al,bh
	shr	al,4
	cmp	al,[address_size]
	jne	invalid_address
      address_component_ok:
	ret
bndldx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	call	take_bnd_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_bnd_mib
	jmp	bndmk_ready
bndstx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	call	take_bnd_mib
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_bnd_register
	mov	[postbyte_register],al
	jmp	bndmk_ready
    take_bnd_mib:
	lods	byte [esi]
	cmp	al,'['
	jne	invalid_operand
	call	get_bnd_size
	call	get_address_prefixes
	call	get_address_component
	cmp	byte [esi-1],']'
	je	bnd_mib_ok
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_operand
	mov	al,[address_sign]
	push	eax ebx ecx edx [address_symbol]
	call	get_address_component
	lods	byte [esi]
	cmp	al,']'
	jne	invalid_operand
	or	dl,bl
	or	dl,[address_sign]
	or	edx,[address_high]
	jnz	invalid_address
	mov	[address_register],bh
	pop	[address_symbol] edx ecx ebx eax
	mov	[address_sign],al
	or	bl,bl
	jz	mib_place_index
	or	bh,bh
	jnz	invalid_address
	cmp	cl,1
	jne	invalid_address
	mov	bh,bl
      mib_place_index:
	mov	bl,[address_register]
	xor	cl,cl
	or	al,al
	jz	bnd_mib_ok
	inc	cl
      bnd_mib_ok:
	ret

take_register:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
convert_register:
	mov	ah,al
	shr	ah,4
	and	al,0Fh
	cmp	ah,8
	je	match_register_size
	cmp	ah,4
	ja	invalid_operand
	cmp	ah,1
	ja	match_register_size
	cmp	al,4
	jb	match_register_size
	or	ah,ah
	jz	high_byte_register
	or	[rex_prefix],40h
      match_register_size:
	cmp	ah,[operand_size]
	je	register_size_ok
	cmp	[operand_size],0
	jne	operand_sizes_do_not_match
	mov	[operand_size],ah
      register_size_ok:
	ret
      high_byte_register:
	mov	ah,1
	or	[rex_prefix],10h
	jmp	match_register_size
convert_fpu_register:
	mov	ah,al
	shr	ah,4
	and	al,111b
	cmp	ah,10
	jne	invalid_operand
	jmp	match_register_size
convert_mmx_register:
	mov	ah,al
	shr	ah,4
	cmp	ah,0Ch
	je	xmm_register
	ja	invalid_operand
	and	al,111b
	cmp	ah,0Bh
	jne	invalid_operand
	mov	ah,8
	jmp	match_register_size
      xmm_register:
	and	al,0Fh
	mov	ah,16
	cmp	al,8
	jb	match_register_size
	cmp	[code_type],64
	jne	invalid_operand
	jmp	match_register_size
convert_xmm_register:
	mov	ah,al
	shr	ah,4
	cmp	ah,0Ch
	je	xmm_register
	jmp	invalid_operand
get_size_operator:
	xor	ah,ah
	cmp	al,11h
	jne	no_size_operator
	mov	[size_declared],1
	lods	word [esi]
	xchg	al,ah
	or	[operand_flags],1
	cmp	ah,[operand_size]
	je	size_operator_ok
	cmp	[operand_size],0
	jne	operand_sizes_do_not_match
	mov	[operand_size],ah
      size_operator_ok:
	ret
      no_size_operator:
	mov	[size_declared],0
	cmp	al,'['
	jne	size_operator_ok
	and	[operand_flags],not 1
	ret
get_jump_operator:
	mov	[jump_type],0
	cmp	al,12h
	jne	jump_operator_ok
	lods	word [esi]
	mov	[jump_type],al
	mov	al,ah
      jump_operator_ok:
	ret
get_address:
	and	[address_size],0
    get_address_of_required_size:
	call	get_address_prefixes
	and	[free_address_range],0
	call	calculate_address
	cmp	byte [esi-1],']'
	jne	invalid_address
	mov	[address_high],edx
	mov	edx,eax
	cmp	[address_size_declared],0
	jne	address_ok
	or	bx,bx
	jnz	clear_address_size
	cmp	[code_type],64
	jne	address_ok
      calculate_relative_address:
	mov	edx,[address_symbol]
	mov	[symbol_identifier],edx
	mov	edx,[address_high]
	mov	ebp,[addressing_space]
	call	calculate_relative_offset
	mov	[address_high],edx
	cdq
	cmp	edx,[address_high]
	je	address_high_ok
	call	recoverable_overflow
      address_high_ok:
	mov	edx,eax
	ror	ecx,16
	mov	cl,[value_type]
	rol	ecx,16
	mov	bx,9900h
      clear_address_size:
	and	ch,not 0Fh
      address_ok:
	ret
get_address_prefixes:
	and	[segment_register],0
	and	[address_size_declared],0
	mov	al,[code_type]
	shr	al,3
	mov	[value_size],al
	mov	al,[esi]
	and	al,11110000b
	cmp	al,60h
	jne	get_address_size_prefix
	lods	byte [esi]
	sub	al,60h
	mov	[segment_register],al
	mov	al,[esi]
	and	al,11110000b
      get_address_size_prefix:
	cmp	al,70h
	jne	address_size_prefix_ok
	lods	byte [esi]
	sub	al,70h
	cmp	al,2
	jb	invalid_address_size
	cmp	al,8
	ja	invalid_address_size
	mov	[value_size],al
	or	[address_size_declared],1
	or	[address_size],al
	cmp	al,[address_size]
	jne	invalid_address_size
      address_size_prefix_ok:
	ret
operand_16bit:
	cmp	[code_type],16
	je	size_prefix_ok
	mov	[operand_prefix],66h
	ret
operand_32bit:
	cmp	[code_type],16
	jne	size_prefix_ok
	mov	[operand_prefix],66h
      size_prefix_ok:
	ret
operand_64bit:
	cmp	[code_type],64
	jne	illegal_instruction
	or	[rex_prefix],48h
	ret
operand_autodetect:
	cmp	al,2
	je	operand_16bit
	cmp	al,4
	je	operand_32bit
	cmp	al,8
	je	operand_64bit
	jmp	invalid_operand_size
store_segment_prefix_if_necessary:
	mov	al,[segment_register]
	or	al,al
	jz	segment_prefix_ok
	cmp	al,4
	ja	segment_prefix_386
	cmp	[code_type],64
	je	segment_prefix_ok
	cmp	al,3
	je	ss_prefix
	jb	segment_prefix_86
	cmp	bl,25h
	je	segment_prefix_86
	cmp	bh,25h
	je	segment_prefix_86
	cmp	bh,45h
	je	segment_prefix_86
	cmp	bh,44h
	je	segment_prefix_86
	ret
      ss_prefix:
	cmp	bl,25h
	je	segment_prefix_ok
	cmp	bh,25h
	je	segment_prefix_ok
	cmp	bh,45h
	je	segment_prefix_ok
	cmp	bh,44h
	je	segment_prefix_ok
	jmp	segment_prefix_86
store_segment_prefix:
	mov	al,[segment_register]
	or	al,al
	jz	segment_prefix_ok
	cmp	al,5
	jae	segment_prefix_386
      segment_prefix_86:
	dec	al
	shl	al,3
	add	al,26h
	stos	byte [edi]
	jmp	segment_prefix_ok
      segment_prefix_386:
	add	al,64h-5
	stos	byte [edi]
      segment_prefix_ok:
	ret
store_instruction_code:
	cmp	[vex_required],0
	jne	store_vex_instruction_code
store_classic_instruction_code:
	mov	al,[operand_prefix]
	or	al,al
	jz	operand_prefix_ok
	stos	byte [edi]
      operand_prefix_ok:
	mov	al,[opcode_prefix]
	or	al,al
	jz	opcode_prefix_ok
	stos	byte [edi]
      opcode_prefix_ok:
	mov	al,[rex_prefix]
	test	al,40h
	jz	rex_prefix_ok
	cmp	[code_type],64
	jne	invalid_operand
	test	al,0B0h
	jnz	disallowed_combination_of_registers
	stos	byte [edi]
      rex_prefix_ok:
	mov	al,[base_code]
	stos	byte [edi]
	cmp	al,0Fh
	jne	instruction_code_ok
      store_extended_code:
	mov	al,[extended_code]
	stos	byte [edi]
	cmp	al,38h
	je	store_supplemental_code
	cmp	al,3Ah
	je	store_supplemental_code
      instruction_code_ok:
	ret
      store_supplemental_code:
	mov	al,[supplemental_code]
	stos	byte [edi]
	ret
store_nomem_instruction:
	test	[postbyte_register],10000b
	jz	nomem_reg_high_code_ok
	or	[vex_required],10h
	and	[postbyte_register],1111b
      nomem_reg_high_code_ok:
	test	[postbyte_register],1000b
	jz	nomem_reg_code_ok
	or	[rex_prefix],44h
	and	[postbyte_register],111b
      nomem_reg_code_ok:
	test	bl,10000b
	jz	nomem_rm_high_code_ok
	or	[rex_prefix],42h
	or	[vex_required],8
	and	bl,1111b
      nomem_rm_high_code_ok:
	test	bl,1000b
	jz	nomem_rm_code_ok
	or	[rex_prefix],41h
	and	bl,111b
      nomem_rm_code_ok:
	and	[displacement_compression],0
	call	store_instruction_code
	mov	al,[postbyte_register]
	shl	al,3
	or	al,bl
	or	al,11000000b
	stos	byte [edi]
	ret
store_instruction:
	mov	[current_offset],edi
	and	[displacement_compression],0
	test	[postbyte_register],10000b
	jz	reg_high_code_ok
	or	[vex_required],10h
	and	[postbyte_register],1111b
      reg_high_code_ok:
	test	[postbyte_register],1000b
	jz	reg_code_ok
	or	[rex_prefix],44h
	and	[postbyte_register],111b
      reg_code_ok:
	cmp	[code_type],64
	jne	address_value_ok
	xor	eax,eax
	bt	edx,31
	sbb	eax,[address_high]
	jz	address_value_ok
	cmp	[address_high],0
	jne	address_value_out_of_range
	test	ch,44h
	jnz	address_value_ok
	test	bx,8080h
	jz	address_value_ok
      address_value_out_of_range:
	call	recoverable_overflow
      address_value_ok:
	call	store_segment_prefix_if_necessary
	test	[vex_required],4
	jnz	address_vsib
	or	bx,bx
	jz	address_immediate
	cmp	bx,9800h
	je	address_rip_based
	cmp	bx,9400h
	je	address_eip_based
	cmp	bx,9900h
	je	address_relative
	mov	al,bl
	or	al,bh
	and	al,11110000b
	cmp	al,80h
	je	postbyte_64bit
	cmp	al,40h
	je	postbyte_32bit
	cmp	al,20h
	jne	invalid_address
	cmp	[code_type],64
	je	invalid_address_size
	call	address_16bit_prefix
	test	ch,22h
	setz	[displacement_compression]
	call	store_instruction_code
	cmp	bl,bh
	jbe	determine_16bit_address
	xchg	bl,bh
      determine_16bit_address:
	cmp	bx,2600h
	je	address_si
	cmp	bx,2700h
	je	address_di
	cmp	bx,2300h
	je	address_bx
	cmp	bx,2500h
	je	address_bp
	cmp	bx,2625h
	je	address_bp_si
	cmp	bx,2725h
	je	address_bp_di
	cmp	bx,2723h
	je	address_bx_di
	cmp	bx,2623h
	jne	invalid_address
      address_bx_si:
	xor	al,al
	jmp	postbyte_16bit
      address_bx_di:
	mov	al,1
	jmp	postbyte_16bit
      address_bp_si:
	mov	al,10b
	jmp	postbyte_16bit
      address_bp_di:
	mov	al,11b
	jmp	postbyte_16bit
      address_si:
	mov	al,100b
	jmp	postbyte_16bit
      address_di:
	mov	al,101b
	jmp	postbyte_16bit
      address_bx:
	mov	al,111b
	jmp	postbyte_16bit
      address_bp:
	mov	al,110b
      postbyte_16bit:
	test	ch,22h
	jnz	address_16bit_value
	or	ch,ch
	jnz	address_sizes_do_not_agree
	cmp	edx,10000h
	jge	value_out_of_range
	cmp	edx,-8000h
	jl	value_out_of_range
	or	dx,dx
	jz	address
	cmp	[displacement_compression],2
	ja	address_8bit_value
	je	address_16bit_value
	cmp	dx,80h
	jb	address_8bit_value
	cmp	dx,-80h
	jae	address_8bit_value
      address_16bit_value:
	or	al,10000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
	mov	eax,edx
	stos	word [edi]
	ret
      address_8bit_value:
	or	al,01000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
	mov	al,dl
	stos	byte [edi]
	ret
      address:
	cmp	al,110b
	je	address_8bit_value
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
	ret
      address_vsib:
	mov	al,bl
	shr	al,4
	test	al,1
	jz	vsib_high_code_ok
	or	[vex_register],10000b
	or	[vex_required],8
	xor	al,1
      vsib_high_code_ok:
	cmp	al,6
	je	vsib_index_ok
	cmp	al,0Ch
	jb	invalid_address
      vsib_index_ok:
	mov	al,bh
	shr	al,4
	cmp	al,4
	je	postbyte_32bit
	cmp	[code_type],64
	je	address_prefix_ok
	test	al,al
	jnz	invalid_address
      postbyte_32bit:
	call	address_32bit_prefix
	jmp	address_prefix_ok
      postbyte_64bit:
	cmp	[code_type],64
	jne	invalid_address_size
      address_prefix_ok:
	cmp	bl,44h
	je	invalid_address
	cmp	bl,84h
	je	invalid_address
	test	bh,1000b
	jz	base_code_ok
	or	[rex_prefix],41h
      base_code_ok:
	test	bl,1000b
	jz	index_code_ok
	or	[rex_prefix],42h
      index_code_ok:
	test	ch,44h or 88h
	setz	[displacement_compression]
	call	store_instruction_code
	or	cl,cl
	jz	only_base_register
      base_and_index:
	mov	al,100b
	xor	ah,ah
	cmp	cl,1
	je	scale_ok
	cmp	cl,2
	je	scale_1
	cmp	cl,4
	je	scale_2
	or	ah,11000000b
	jmp	scale_ok
      scale_2:
	or	ah,10000000b
	jmp	scale_ok
      scale_1:
	or	ah,01000000b
      scale_ok:
	or	bh,bh
	jz	only_index_register
	and	bl,111b
	shl	bl,3
	or	ah,bl
	and	bh,111b
	or	ah,bh
      sib_ready:
	test	ch,44h or 88h
	jnz	sib_address_32bit_value
	or	ch,ch
	jnz	address_sizes_do_not_agree
	cmp	bh,5
	je	address_value
	or	edx,edx
	jz	sib_address
      address_value:
	cmp	[displacement_compression],2
	ja	sib_address_8bit_value
	je	sib_address_32bit_value
	cmp	edx,80h
	jb	sib_address_8bit_value
	cmp	edx,-80h
	jnb	sib_address_8bit_value
      sib_address_32bit_value:
	or	al,10000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	word [edi]
	jmp	store_address_32bit_value
      sib_address_8bit_value:
	or	al,01000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	word [edi]
	mov	al,dl
	stos	byte [edi]
	ret
      sib_address:
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	word [edi]
	ret
      only_index_register:
	or	ah,101b
	and	bl,111b
	shl	bl,3
	or	ah,bl
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	word [edi]
	test	ch,44h or 88h
	jnz	store_address_32bit_value
	or	ch,ch
	jnz	invalid_address_size
	cmp	[displacement_compression],2
	jbe	store_address_32bit_value
	mov	edx,[uncompressed_displacement]
	jmp	store_address_32bit_value
      zero_index_register:
	mov	bl,4
	mov	cl,1
	jmp	base_and_index
      only_base_register:
	mov	al,bh
	and	al,111b
	cmp	al,4
	je	zero_index_register
	test	ch,44h or 88h
	jnz	simple_address_32bit_value
	or	ch,ch
	jnz	address_sizes_do_not_agree
	or	edx,edx
	jz	simple_address
	cmp	[displacement_compression],2
	ja	simple_address_8bit_value
	je	simple_address_32bit_value
	cmp	edx,80h
	jb	simple_address_8bit_value
	cmp	edx,-80h
	jnb	simple_address_8bit_value
      simple_address_32bit_value:
	or	al,10000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
	jmp	store_address_32bit_value
      simple_address_8bit_value:
	or	al,01000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
	mov	al,dl
	stos	byte [edi]
	ret
      simple_address:
	cmp	al,5
	je	simple_address_8bit_value
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
	ret
      address_immediate:
	cmp	[code_type],64
	je	address_immediate_sib
	test	ch,44h or 88h
	jnz	address_immediate_32bit
	test	ch,22h
	jnz	address_immediate_16bit
	or	ch,ch
	jnz	invalid_address_size
	cmp	[code_type],16
	je	addressing_16bit
      address_immediate_32bit:
	call	address_32bit_prefix
	call	store_instruction_code
      store_immediate_address:
	mov	al,101b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
      store_address_32bit_value:
	test	ch,0F0h
	jz	address_32bit_relocation_ok
	mov	eax,ecx
	shr	eax,16
	cmp	al,4
	jne	address_32bit_relocation
	mov	al,2
      address_32bit_relocation:
	xchg	[value_type],al
	mov	ebx,[address_symbol]
	xchg	ebx,[symbol_identifier]
	call	mark_relocation
	mov	[value_type],al
	mov	[symbol_identifier],ebx
      address_32bit_relocation_ok:
	mov	eax,edx
	stos	dword [edi]
	ret
      store_address_64bit_value:
	test	ch,0F0h
	jz	address_64bit_relocation_ok
	mov	eax,ecx
	shr	eax,16
	xchg	[value_type],al
	mov	ebx,[address_symbol]
	xchg	ebx,[symbol_identifier]
	call	mark_relocation
	mov	[value_type],al
	mov	[symbol_identifier],ebx
      address_64bit_relocation_ok:
	mov	eax,edx
	stos	dword [edi]
	mov	eax,[address_high]
	stos	dword [edi]
	ret
      address_immediate_sib:
	test	ch,44h
	jnz	address_immediate_sib_32bit
	test	ch,not 88h
	jnz	invalid_address_size
      address_immediate_sib_store:
	call	store_instruction_code
	mov	al,100b
	mov	ah,100101b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	word [edi]
	jmp	store_address_32bit_value
      address_immediate_sib_32bit:
	test	ecx,0FF0000h
	jnz	address_immediate_sib_nosignextend
	test	edx,80000000h
	jz	address_immediate_sib_store
      address_immediate_sib_nosignextend:
	call	address_32bit_prefix
	jmp	address_immediate_sib_store
      address_eip_based:
	mov	al,67h
	stos	byte [edi]
      address_rip_based:
	cmp	[code_type],64
	jne	invalid_address
	call	store_instruction_code
	jmp	store_immediate_address
      address_relative:
	call	store_instruction_code
	movzx	eax,[immediate_size]
	add	eax,edi
	sub	eax,[current_offset]
	add	eax,5
	sub	edx,eax
	jno	@f
	call	recoverable_overflow
      @@:
	mov	al,101b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
	shr	ecx,16
	xchg	[value_type],cl
	mov	ebx,[address_symbol]
	xchg	ebx,[symbol_identifier]
	mov	eax,edx
	call	mark_relocation
	mov	[value_type],cl
	mov	[symbol_identifier],ebx
	stos	dword [edi]
	ret
      addressing_16bit:
	cmp	edx,10000h
	jge	address_immediate_32bit
	cmp	edx,-8000h
	jl	address_immediate_32bit
	movzx	edx,dx
      address_immediate_16bit:
	call	address_16bit_prefix
	call	store_instruction_code
	mov	al,110b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stos	byte [edi]
	mov	eax,edx
	stos	word [edi]
	cmp	edx,10000h
	jge	value_out_of_range
	cmp	edx,-8000h
	jl	value_out_of_range
	ret
      address_16bit_prefix:
	cmp	[code_type],16
	je	instruction_prefix_ok
	mov	al,67h
	stos	byte [edi]
	ret
      address_32bit_prefix:
	cmp	[code_type],32
	je	instruction_prefix_ok
	mov	al,67h
	stos	byte [edi]
      instruction_prefix_ok:
	ret
store_instruction_with_imm8:
	mov	[immediate_size],1
	call	store_instruction
	mov	al,byte [value]
	stos	byte [edi]
	ret
store_instruction_with_imm16:
	mov	[immediate_size],2
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stos	word [edi]
	ret
store_instruction_with_imm32:
	mov	[immediate_size],4
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stos	dword [edi]
	ret


# AVX instructions

avx_single_source_pd_instruction_er_evex:
	or	[vex_required],8
avx_single_source_pd_instruction_er:
	or	[operand_flags],2+4+8
	jmp	avx_pd_instruction
avx_single_source_pd_instruction_sae_evex:
	or	[vex_required],8
	or	[operand_flags],2+4
	jmp	avx_pd_instruction
avx_pd_instruction_imm8:
	mov	[immediate_size],1
	jmp	avx_pd_instruction
avx_pd_instruction_er:
	or	[operand_flags],8
avx_pd_instruction_sae:
	or	[operand_flags],4
avx_pd_instruction:
	mov	[opcode_prefix],66h
	or	[rex_prefix],80h
	mov	cx,0800h
	jmp	avx_instruction_with_broadcast
avx_pd_instruction_38_evex:
	or	[vex_required],8
	mov	[supplemental_code],al
	mov	al,38h
	jmp	avx_pd_instruction
avx_cvtps2dq_instruction:
	mov	[opcode_prefix],66h
	jmp	avx_single_source_ps_instruction_er
avx_cvtudq2ps_instruction:
	mov	[opcode_prefix],0F2h
avx_single_source_ps_instruction_er_evex:
	or	[vex_required],8
avx_single_source_ps_instruction_er:
	or	[operand_flags],2+4+8
	jmp	avx_ps_instruction
avx_single_source_ps_instruction_noevex:
	or	[operand_flags],2
	or	[vex_required],2
	jmp	avx_ps_instruction
avx_ps_instruction_imm8:
	mov	[immediate_size],1
	jmp	avx_ps_instruction
avx_ps_instruction_er:
	or	[operand_flags],8
avx_ps_instruction_sae:
	or	[operand_flags],4
avx_ps_instruction:
	mov	cx,0400h
	jmp	avx_instruction_with_broadcast
avx_ps_instruction_66_38_evex:
	or	[vex_required],8
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	mov	al,38h
	jmp	avx_ps_instruction
avx_sd_instruction_er:
	or	[operand_flags],8
avx_sd_instruction_sae:
	or	[operand_flags],4
avx_sd_instruction:
	mov	[opcode_prefix],0F2h
	or	[rex_prefix],80h
	mov	cl,8
	jmp	avx_instruction
avx_ss_instruction_er:
	or	[operand_flags],8
avx_ss_instruction_sae:
	or	[operand_flags],4
avx_ss_instruction:
	mov	[opcode_prefix],0F3h
	mov	cl,4
	jmp	avx_instruction
avx_ss_instruction_noevex:
	or	[vex_required],2
	jmp	avx_ss_instruction
avx_single_source_q_instruction_38_evex:
	or	[operand_flags],2
avx_q_instruction_38_evex:
	or	[vex_required],8
avx_q_instruction_38:
	mov	[supplemental_code],al
	mov	al,38h
	jmp	avx_q_instruction
avx_q_instruction_38_w1_evex:
	or	[vex_required],8
avx_q_instruction_38_w1:
	or	[rex_prefix],8
	jmp	avx_q_instruction_38
avx_q_instruction_3a_imm8_evex:
	mov	[immediate_size],1
	or	[vex_required],8
	mov	[supplemental_code],al
	mov	al,3Ah
	jmp	avx_q_instruction
avx_q_instruction_evex:
	or	[vex_required],8
avx_q_instruction:
	or	[rex_prefix],80h
	mov	ch,8
	jmp	avx_pi_instruction
avx_single_source_d_instruction_38_evex:
	or	[vex_required],8
avx_single_source_d_instruction_38:
	or	[operand_flags],2
	jmp	avx_d_instruction_38
avx_d_instruction_38_evex:
	or	[vex_required],8
avx_d_instruction_38:
	mov	[supplemental_code],al
	mov	al,38h
	jmp	avx_d_instruction
avx_d_instruction_3a_imm8_evex:
	mov	[immediate_size],1
	or	[vex_required],8
	mov	[supplemental_code],al
	mov	al,3Ah
	jmp	avx_d_instruction
avx_single_source_d_instruction_imm8:
	or	[operand_flags],2
	mov	[immediate_size],1
	jmp	avx_d_instruction
avx_d_instruction_evex:
	or	[vex_required],8
avx_d_instruction:
	mov	ch,4
	jmp	avx_pi_instruction
avx_single_source_bw_instruction_38:
	or	[operand_flags],2
avx_bw_instruction_38:
	mov	[supplemental_code],al
	mov	al,38h
avx_bw_instruction:
	xor	ch,ch
      avx_pi_instruction:
	mov	[opcode_prefix],66h
	xor	cl,cl
	jmp	avx_instruction_with_broadcast
avx_bw_instruction_38_w1_evex:
	or	[rex_prefix],8
avx_bw_instruction_38_evex:
	or	[vex_required],8
	jmp	avx_bw_instruction_38
avx_pd_instruction_noevex:
	xor	cl,cl
	or	[vex_required],2
	mov	[opcode_prefix],66h
	jmp	avx_instruction
avx_ps_instruction_noevex:
	or	[vex_required],2
	mov	[opcode_prefix],0F2h
	xor	cl,cl
	jmp	avx_instruction
avx_instruction:
	xor	ch,ch
      avx_instruction_with_broadcast:
	mov	[mmx_size],cl
	mov	[broadcast_size],ch
	mov	[base_code],0Fh
	mov	[extended_code],al
      avx_xop_common:
	or	[vex_required],1
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
      avx_reg:
	lods	byte [esi]
	call	convert_avx_register
	mov	[postbyte_register],al
	call	take_avx512_mask
      avx_vex_reg:
	test	[operand_flags],2
	jnz	avx_vex_reg_ok
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[vex_register],al
      avx_vex_reg_ok:
	mov	al,[mmx_size]
	or	al,al
	jz	avx_regs_size_ok
	mov	ah,[operand_size]
	or	ah,ah
	jz	avx_regs_size_ok
	cmp	al,ah
	je	avx_regs_size_ok
	ja	invalid_operand_size
	cmp	ah,16
	jne	invalid_operand_size
      avx_regs_size_ok:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
      avx_regs_rm:
	call	take_avx_rm
	jc	avx_regs_reg
	mov	al,[immediate_size]
	cmp	al,1
	je	mmx_imm8
	jb	instruction_ready
	cmp	al,-4
	je	sse_cmp_mem_ok
	cmp	byte [esi],','
	jne	invalid_operand
	inc	esi
	call	take_avx_register
	shl	al,4
	jc	invalid_operand
	or	byte [value],al
	test	al,80h
	jz	avx_regs_mem_reg_store
	cmp	[code_type],64
	jne	invalid_operand
      avx_regs_mem_reg_store:
	call	take_imm4_if_needed
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      avx_regs_reg:
	mov	bl,al
	call	take_avx512_rounding
	mov	al,[immediate_size]
	cmp	al,1
	je	mmx_nomem_imm8
	jb	nomem_instruction_ready
	cmp	al,-4
	je	sse_cmp_nomem_ok
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	al,bl
	shl	al,4
	jc	invalid_operand
	or	byte [value],al
	test	al,80h
	jz	avx_regs_reg_
	cmp	[code_type],64
	jne	invalid_operand
      avx_regs_reg_:
	call	take_avx_rm
	jc	avx_regs_reg_reg
	cmp	[immediate_size],-2
	jg	invalid_operand
	or	[rex_prefix],8
	call	take_imm4_if_needed
	call	store_instruction_with_imm8
	jmp	instruction_assembled
      avx_regs_reg_reg:
	shl	al,4
	jc	invalid_operand
	and	byte [value],1111b
	or	byte [value],al
	call	take_imm4_if_needed
	call	store_nomem_instruction
	mov	al,byte [value]
	stos	byte [edi]
	jmp	instruction_assembled
      take_avx_rm:
	xor	cl,cl
	xchg	cl,[operand_size]
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	take_avx_mem
	cmp	al,10h
	jne	invalid_operand
	mov	[operand_size],cl
	lods	byte [esi]
	call	convert_avx_register
	or	cl,cl
	jnz	avx_reg_ok
	or	cl,[mmx_size]
	jz	avx_reg_ok
	cmp	ah,cl
	je	avx_reg_ok
	jb	invalid_operand_size
	cmp	ah,16
	jne	invalid_operand_size
      avx_reg_ok:
	stc
	ret
      take_avx_mem:
	push	ecx
	call	get_address
	cmp	byte [esi],'{'
	jne	avx_mem_ok
	inc	esi
	lods	byte [esi]
	cmp	al,1Fh
	jne	invalid_operand
	mov	al,[esi]
	shr	al,4
	cmp	al,1
	jne	invalid_operand
	mov	al,[mmx_size]
	or	al,al
	jnz	avx_mem_broadcast_check
	mov	eax,[esp]
	or	al,al
	jnz	avx_mem_broadcast_check
	mov	al,[broadcast_size]
	mov	[mmx_size],al
	mov	ah,cl
	lods	byte [esi]
	and	al,1111b
	mov	cl,al
	mov	al,[broadcast_size]
	shl	al,cl
	mov	[esp],al
	mov	cl,ah
	jmp	avx_mem_broadcast_ok
      avx_mem_broadcast_check:
	bsf	eax,eax
	xchg	al,[broadcast_size]
	mov	[mmx_size],al
	bsf	eax,eax
	jz	invalid_operand
	mov	ah,[broadcast_size]
	sub	ah,al
	lods	byte [esi]
	and	al,1111b
	cmp	al,ah
	jne	invalid_operand_size
      avx_mem_broadcast_ok:
	or	[vex_required],40h
	lods	byte [esi]
	cmp	al,'}'
	jne	invalid_operand
      avx_mem_ok:
	pop	eax
	or	al,al
	jz	avx_mem_size_deciding
	xchg	al,[operand_size]
	cmp	[mmx_size],0
	jne	avx_mem_size_enforced
	or	al,al
	jz	avx_mem_size_ok
	cmp	al,[operand_size]
	jne	operand_sizes_do_not_match
      avx_mem_size_ok:
	clc
	ret
      avx_mem_size_deciding:
	mov	al,[operand_size]
	cmp	[mmx_size],0
	jne	avx_mem_size_enforced
	or	al,al
	jz	operand_size_not_specified
	cmp	al,16
	je	avx_mem_size_ok
	cmp	al,32
	je	avx_mem_size_ok
	cmp	al,64
	je	avx_mem_size_ok
	jmp	invalid_operand_size
      avx_mem_size_enforced:
	or	al,al
	jz	avx_mem_size_ok
	cmp	al,[mmx_size]
	je	avx_mem_size_ok
	jmp	invalid_operand_size
      take_imm4_if_needed:
	cmp	[immediate_size],-3
	jne	imm4_ok
	push	ebx ecx edx
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	test	al,11110000b
	jnz	value_out_of_range
	or	byte [value],al
	pop	edx ecx ebx
      imm4_ok:
	ret
      take_avx512_mask:
	cmp	byte [esi],'{'
	jne	avx512_masking_ok
	test	[operand_flags],10h
	jnz	invalid_operand
	inc	esi
	lods	byte [esi]
	cmp	al,14h
	jne	invalid_operand
	lods	byte [esi]
	mov	ah,al
	shr	ah,4
	cmp	ah,5
	jne	invalid_operand
	or	al,al
	jz	invalid_operand
	and	al,111b
	mov	[mask_register],al
	or	[vex_required],20h
	lods	byte [esi]
	cmp	al,'}'
	jne	invalid_operand
	cmp	byte [esi],'{'
	jne	avx512_masking_ok
	test	[operand_flags],20h
	jnz	invalid_operand
	inc	esi
	lods	byte [esi]
	cmp	al,1Fh
	jne	invalid_operand
	lods	byte [esi]
	or	al,al
	jnz	invalid_operand
	or	[mask_register],80h
	lods	byte [esi]
	cmp	al,'}'
	jne	invalid_operand
      avx512_masking_ok:
	retn
      take_avx512_rounding:
	test	[operand_flags],4+8
	jz	avx512_rounding_done
	cmp	[mmx_size],0
	jne	avx512_rounding_allowed
	cmp	[operand_size],64
	jne	avx512_rounding_done
      avx512_rounding_allowed:
	cmp	byte [esi],','
	jne	avx512_rounding_done
	cmp	byte [esi+1],'{'
	jne	avx512_rounding_done
	add	esi,2
	mov	[rounding_mode],0
	or	[vex_required],40h+80h
	test	[operand_flags],8
	jz	take_sae
	lods	byte [esi]
	cmp	al,1Fh
	jne	invalid_operand
	lods	byte [esi]
	mov	ah,al
	shr	ah,4
	cmp	ah,2
	jne	invalid_operand
	and	al,11b
	mov	[rounding_mode],al
	lods	byte [esi]
	cmp	al,'-'
	jne	invalid_operand
      take_sae:
	lods	byte [esi]
	cmp	al,1Fh
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,30h
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,'}'
	jne	invalid_operand
      avx512_rounding_done:
	retn

avx_movdqu_instruction:
	mov	ah,0F3h
	jmp	avx_movdq_instruction
avx_movdqa_instruction:
	mov	ah,66h
      avx_movdq_instruction:
	mov	[opcode_prefix],ah
	or	[vex_required],2
	jmp	avx_movps_instruction
avx512_movdqu16_instruction:
	or	[rex_prefix],8
avx512_movdqu8_instruction:
	mov	ah,0F2h
	jmp	avx_movdq_instruction_evex
avx512_movdqu64_instruction:
	or	[rex_prefix],8
avx512_movdqu32_instruction:
	mov	ah,0F3h
	jmp	avx_movdq_instruction_evex
avx512_movdqa64_instruction:
	or	[rex_prefix],8
avx512_movdqa32_instruction:
	mov	ah,66h
      avx_movdq_instruction_evex:
	mov	[opcode_prefix],ah
	or	[vex_required],8
	jmp	avx_movps_instruction
avx_movpd_instruction:
	mov	[opcode_prefix],66h
	or	[rex_prefix],80h
avx_movps_instruction:
	or	[operand_flags],2
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	xor	al,al
	mov	[mmx_size],al
	mov	[broadcast_size],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_reg
	inc	[extended_code]
	test	[extended_code],1
	jnz	avx_mem
	add	[extended_code],-1+10h
      avx_mem:
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	[operand_flags],20h
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[postbyte_register],al
	jmp	instruction_ready
avx_movntpd_instruction:
	or	[rex_prefix],80h
avx_movntdq_instruction:
	mov	[opcode_prefix],66h
avx_movntps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	or	[operand_flags],10h
	mov	[mmx_size],0
	lods	byte [esi]
	call	get_size_operator
	jmp	avx_mem
avx_compress_q_instruction:
	or	[rex_prefix],8
avx_compress_d_instruction:
	or	[vex_required],8
	mov	[mmx_size],0
	call	setup_66_0f_38
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	avx_mem
	lods	byte [esi]
	call	convert_avx_register
	mov	bl,al
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[postbyte_register],al
	jmp	nomem_instruction_ready
avx_lddqu_instruction:
	mov	ah,0F2h
	or	[vex_required],2
      avx_load_instruction:
	mov	[opcode_prefix],ah
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],0
	or	[vex_required],1
	call	take_avx_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	jmp	instruction_ready
avx_movntdqa_instruction:
	mov	[supplemental_code],al
	mov	al,38h
	mov	ah,66h
	jmp	avx_load_instruction
avx_movq_instruction:
	or	[rex_prefix],8
	mov	[mmx_size],8
	jmp	avx_mov_instruction
avx_movd_instruction:
	mov	[mmx_size],4
      avx_mov_instruction:
	or	[vex_required],1
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],7Eh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_movd_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[mmx_size]
	not	al
	and	[operand_size],al
	jnz	invalid_operand_size
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_avx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	cmp	[mmx_size],8
	jne	instruction_ready
	and	[rex_prefix],not 8
	or	[rex_prefix],80h
	mov	[extended_code],0D6h
	jmp	instruction_ready
      avx_movd_reg:
	lods	byte [esi]
	cmp	al,0C0h
	jae	avx_movd_xmmreg
	call	convert_register
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	mov	[operand_size],0
	mov	bl,al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_avx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	jmp	nomem_instruction_ready
      avx_movd_xmmreg:
	sub	[extended_code],10h
	call	convert_avx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_movd_xmmreg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[mmx_size]
	cmp	al,8
	jne	avx_movd_xmmreg_mem_ready
	call	avx_movq_xmmreg_xmmreg_opcode
      avx_movd_xmmreg_mem_ready:
	not	al
	test	[operand_size],al
	jnz	invalid_operand_size
	jmp	instruction_ready
      avx_movd_xmmreg_reg:
	lods	byte [esi]
	cmp	al,0C0h
	jae	avx_movq_xmmreg_xmmreg
	call	convert_register
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	mov	bl,al
	jmp	nomem_instruction_ready
      avx_movq_xmmreg_xmmreg:
	cmp	[mmx_size],8
	jne	invalid_operand
	call	avx_movq_xmmreg_xmmreg_opcode
	call	convert_avx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	bl,al
	jmp	nomem_instruction_ready
      avx_movq_xmmreg_xmmreg_opcode:
	and	[rex_prefix],not 8
	or	[rex_prefix],80h
	add	[extended_code],10h
	mov	[opcode_prefix],0F3h
	ret
avx_movddup_instruction:
	or	[vex_required],1
	mov	[opcode_prefix],0F2h
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[rex_prefix],80h
	xor	al,al
	mov	[mmx_size],al
	mov	[broadcast_size],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_avx_register
	mov	[postbyte_register],al
	cmp	ah,16
	ja	avx_movddup_size_ok
	mov	[mmx_size],8
      avx_movddup_size_ok:
	call	take_avx512_mask
	jmp	avx_vex_reg_ok
avx_movlpd_instruction:
	mov	[opcode_prefix],66h
	or	[rex_prefix],80h
avx_movlps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],8
	mov	[broadcast_size],0
	or	[vex_required],1
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	avx_movlps_mem
	lods	byte [esi]
	call	convert_avx_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[vex_register],al
	cmp	[operand_size],16
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_rm
	jc	invalid_operand
	jmp	instruction_ready
      avx_movlps_mem:
	cmp	al,'['
	jne	invalid_operand
	call	get_address
      avx_movlps_mem_:
	mov	al,[operand_size]
	or	al,al
	jz	avx_movlps_mem_size_ok
	cmp	al,[mmx_size]
	jne	invalid_operand_size
	mov	[operand_size],0
      avx_movlps_mem_size_ok:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	cmp	ah,16
	jne	invalid_operand
	mov	[postbyte_register],al
	inc	[extended_code]
	jmp	instruction_ready
avx_movhlps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	call	take_avx_register
	cmp	ah,16
	jne	invalid_operand
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	bl,al
	jmp	nomem_instruction_ready
avx_movsd_instruction:
	mov	al,0F2h
	mov	cl,8
	or	[rex_prefix],80h
	jmp	avx_movs_instruction
avx_movss_instruction:
	mov	al,0F3h
	mov	cl,4
      avx_movs_instruction:
	mov	[opcode_prefix],al
	mov	[mmx_size],cl
	or	[vex_required],1
	mov	[base_code],0Fh
	mov	[extended_code],10h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	avx_movs_mem
	lods	byte [esi]
	call	convert_avx_register
	cmp	ah,16
	jne	invalid_operand
	mov	[postbyte_register],al
	call	take_avx512_mask
	xor	cl,cl
	xchg	cl,[operand_size]
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	avx_movs_reg_mem
	mov	[operand_size],cl
	lods	byte [esi]
	call	convert_avx_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	bl,al
	cmp	bl,8
	jb	nomem_instruction_ready
	inc	[extended_code]
	xchg	bl,[postbyte_register]
	jmp	nomem_instruction_ready
      avx_movs_reg_mem:
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	avx_movs_reg_mem_ok
	cmp	al,[mmx_size]
	jne	invalid_operand_size
      avx_movs_reg_mem_ok:
	jmp	instruction_ready
      avx_movs_mem:
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	[operand_flags],20h
	call	take_avx512_mask
	jmp	avx_movlps_mem_

avx_comiss_instruction:
	or	[operand_flags],2+4+10h
	mov	cl,4
	jmp	avx_instruction
avx_comisd_instruction:
	or	[operand_flags],2+4+10h
	mov	[opcode_prefix],66h
	or	[rex_prefix],80h
	mov	cl,8
	jmp	avx_instruction
avx_movshdup_instruction:
	or	[operand_flags],2
	mov	[opcode_prefix],0F3h
	xor	cl,cl
	jmp	avx_instruction
avx_cvtqq2pd_instruction:
	mov	[opcode_prefix],0F3h
	or	[vex_required],8
	or	[operand_flags],2+4+8
	or	[rex_prefix],8
	mov	cx,0800h
	jmp	avx_instruction_with_broadcast
avx_pshuf_w_instruction:
	mov	[opcode_prefix],al
	or	[operand_flags],2
	mov	[immediate_size],1
	mov	al,70h
	xor	cl,cl
	jmp	avx_instruction
avx_single_source_128bit_instruction_38_noevex:
	or	[operand_flags],2
avx_128bit_instruction_38_noevex:
	mov	cl,16
	jmp	avx_instruction_38_noevex
avx_single_source_instruction_38_noevex:
	or	[operand_flags],2
	jmp	avx_pi_instruction_38_noevex
avx_pi_instruction_38_noevex:
	xor	cl,cl
      avx_instruction_38_noevex:
	or	[vex_required],2
      avx_instruction_38:
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	mov	al,38h
	jmp	avx_instruction
avx_ss_instruction_3a_imm8_noevex:
	mov	cl,4
	jmp	avx_instruction_3a_imm8_noevex
avx_sd_instruction_3a_imm8_noevex:
	mov	cl,8
	jmp	avx_instruction_3a_imm8_noevex
avx_single_source_128bit_instruction_3a_imm8_noevex:
	or	[operand_flags],2
avx_128bit_instruction_3a_imm8_noevex:
	mov	cl,16
	jmp	avx_instruction_3a_imm8_noevex
avx_triple_source_instruction_3a_noevex:
	xor	cl,cl
	mov	[immediate_size],-1
	mov	byte [value],0
	jmp	avx_instruction_3a_noevex
avx_single_source_instruction_3a_imm8_noevex:
	or	[operand_flags],2
avx_pi_instruction_3a_imm8_noevex:
	xor	cl,cl
      avx_instruction_3a_imm8_noevex:
	mov	[immediate_size],1
      avx_instruction_3a_noevex:
	or	[vex_required],2
      avx_instruction_3a:
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	mov	al,3Ah
	jmp	avx_instruction
avx_pi_instruction_3a_imm8:
	xor	cl,cl
	mov	[immediate_size],1
	jmp	avx_instruction_3a
avx_pclmulqdq_instruction:
	mov	byte [value],al
	mov	[immediate_size],-4
	or	[vex_required],2
	mov	cl,16
	mov	al,44h
	jmp	avx_instruction_3a

avx512_single_source_pd_instruction_sae_imm8:
	or	[operand_flags],2
avx512_pd_instruction_sae_imm8:
	or	[rex_prefix],8
	mov	cx,0800h
	jmp	avx512_instruction_sae_imm8
avx512_single_source_ps_instruction_sae_imm8:
	or	[operand_flags],2
avx512_ps_instruction_sae_imm8:
	mov	cx,0400h
	jmp	avx512_instruction_sae_imm8
avx512_sd_instruction_sae_imm8:
	or	[rex_prefix],8
	mov	cx,0008h
	jmp	avx512_instruction_sae_imm8
avx512_ss_instruction_sae_imm8:
	mov	cx,0004h
      avx512_instruction_sae_imm8:
	or	[operand_flags],4
      avx512_instruction_imm8:
	or	[vex_required],8
	mov	[opcode_prefix],66h
	mov	[immediate_size],1
	mov	[supplemental_code],al
	mov	al,3Ah
	jmp	avx_instruction_with_broadcast
avx512_pd_instruction_er:
	or	[operand_flags],4+8
	jmp	avx512_pd_instruction
avx512_single_source_pd_instruction_sae:
	or	[operand_flags],4
avx512_single_source_pd_instruction:
	or	[operand_flags],2
avx512_pd_instruction:
	or	[rex_prefix],8
	mov	cx,0800h
	jmp	avx512_instruction
avx512_ps_instruction_er:
	or	[operand_flags],4+8
	jmp	avx512_ps_instruction
avx512_single_source_ps_instruction_sae:
	or	[operand_flags],4
avx512_single_source_ps_instruction:
	or	[operand_flags],2
avx512_ps_instruction:
	mov	cx,0400h
	jmp	avx512_instruction
avx512_sd_instruction_er:
	or	[operand_flags],8
avx512_sd_instruction_sae:
	or	[operand_flags],4
avx512_sd_instruction:
	or	[rex_prefix],8
	mov	cx,0008h
	jmp	avx512_instruction
avx512_ss_instruction_er:
	or	[operand_flags],8
avx512_ss_instruction_sae:
	or	[operand_flags],4
avx512_ss_instruction:
	mov	cx,0004h
      avx512_instruction:
	or	[vex_required],8
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	mov	al,38h
	jmp	avx_instruction_with_broadcast
avx512_exp2pd_instruction:
	or	[rex_prefix],8
	or	[operand_flags],2+4
	mov	cx,0840h
	jmp	avx512_instruction
avx512_exp2ps_instruction:
	or	[operand_flags],2+4
	mov	cx,0440h
	jmp	avx512_instruction

fma_instruction_pd:
	or	[rex_prefix],8
	mov	cx,0800h
	jmp	fma_instruction
fma_instruction_ps:
	mov	cx,0400h
	jmp	fma_instruction
fma_instruction_sd:
	or	[rex_prefix],8
	mov	cx,0008h
	jmp	fma_instruction
fma_instruction_ss:
	mov	cx,0004h
      fma_instruction:
	or	[operand_flags],4+8
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	mov	al,38h
	jmp	avx_instruction_with_broadcast

fma4_instruction_p:
	xor	cl,cl
	jmp	fma4_instruction
fma4_instruction_sd:
	mov	cl,8
	jmp	fma4_instruction
fma4_instruction_ss:
	mov	cl,4
      fma4_instruction:
	mov	[immediate_size],-2
	mov	byte [value],0
	jmp	avx_instruction_3a_noevex

avx_cmp_pd_instruction:
	mov	[opcode_prefix],66h
	or	[rex_prefix],80h
	mov	cx,0800h
	jmp	avx_cmp_instruction
avx_cmp_ps_instruction:
	mov	cx,0400h
	jmp	avx_cmp_instruction
avx_cmp_sd_instruction:
	mov	[opcode_prefix],0F2h
	or	[rex_prefix],80h
	mov	cx,0008h
	jmp	avx_cmp_instruction
avx_cmp_ss_instruction:
	mov	[opcode_prefix],0F3h
	mov	cx,0004h
      avx_cmp_instruction:
	mov	byte [value],al
	mov	[immediate_size],-4
	or	[operand_flags],4+20h
	mov	al,0C2h
	jmp	avx_cmp_common
avx_cmpeqq_instruction:
	or	[rex_prefix],80h
	mov	ch,8
	mov	[supplemental_code],al
	mov	al,38h
	jmp	avx_cmp_pi_instruction
avx_cmpeqd_instruction:
	mov	ch,4
	jmp	avx_cmp_pi_instruction
avx_cmpeqb_instruction:
	xor	ch,ch
	jmp	avx_cmp_pi_instruction
avx512_cmp_uq_instruction:
	or	[rex_prefix],8
	mov	ch,8
	mov	ah,1Eh
	jmp	avx_cmp_pi_instruction_evex
avx512_cmp_ud_instruction:
	mov	ch,4
	mov	ah,1Eh
	jmp	avx_cmp_pi_instruction_evex
avx512_cmp_q_instruction:
	or	[rex_prefix],8
	mov	ch,8
	mov	ah,1Fh
	jmp	avx_cmp_pi_instruction_evex
avx512_cmp_d_instruction:
	mov	ch,4
	mov	ah,1Fh
	jmp	avx_cmp_pi_instruction_evex
avx512_cmp_uw_instruction:
	or	[rex_prefix],8
avx512_cmp_ub_instruction:
	xor	ch,ch
	mov	ah,3Eh
	jmp	avx_cmp_pi_instruction_evex
avx512_cmp_w_instruction:
	or	[rex_prefix],8
avx512_cmp_b_instruction:
	xor	ch,ch
	mov	ah,3Fh
      avx_cmp_pi_instruction_evex:
	mov	byte [value],al
	mov	[immediate_size],-4
	mov	[supplemental_code],ah
	mov	al,3Ah
	or	[vex_required],8
      avx_cmp_pi_instruction:
	xor	cl,cl
	or	[operand_flags],20h
	mov	[opcode_prefix],66h
      avx_cmp_common:
	mov	[mmx_size],cl
	mov	[broadcast_size],ch
	mov	[extended_code],al
	mov	[base_code],0Fh
	lods	byte [esi]
	call	get_size_operator
	cmp	al,14h
	je	avx_maskreg
	cmp	al,10h
	jne	invalid_operand
	or	[vex_required],2
	jmp	avx_reg
      avx_maskreg:
	cmp	[operand_size],0
	jne	invalid_operand_size
	or	[vex_required],8
	lods	byte [esi]
	call	convert_mask_register
	mov	[postbyte_register],al
	call	take_avx512_mask
	jmp	avx_vex_reg
avx512_fpclasspd_instruction:
	or	[rex_prefix],8
	mov	cx,0800h
	jmp	avx_fpclass_instruction
avx512_fpclassps_instruction:
	mov	cx,0400h
	jmp	avx_fpclass_instruction
avx512_fpclasssd_instruction:
	or	[rex_prefix],8
	mov	cx,0008h
	jmp	avx_fpclass_instruction
avx512_fpclassss_instruction:
	mov	cx,0004h
      avx_fpclass_instruction:
	mov	[broadcast_size],ch
	mov	[mmx_size],cl
	or	[operand_flags],2
	call	setup_66_0f_3a
	mov	[immediate_size],1
	lods	byte [esi]
	cmp	al,14h
	je	avx_maskreg
	jmp	invalid_operand
avx512_ptestnmd_instruction:
	mov	ch,4
	jmp	avx512_ptestnm_instruction
avx512_ptestnmq_instruction:
	or	[rex_prefix],8
	mov	ch,8
	jmp	avx512_ptestnm_instruction
avx512_ptestnmw_instruction:
	or	[rex_prefix],8
avx512_ptestnmb_instruction:
	xor	ch,ch
      avx512_ptestnm_instruction:
	mov	ah,0F3h
	jmp	avx512_ptest_instruction
avx512_ptestmd_instruction:
	mov	ch,4
	jmp	avx512_ptestm_instruction
avx512_ptestmq_instruction:
	or	[rex_prefix],8
	mov	ch,8
	jmp	avx512_ptestm_instruction
avx512_ptestmw_instruction:
	or	[rex_prefix],8
avx512_ptestmb_instruction:
	xor	ch,ch
      avx512_ptestm_instruction:
	mov	ah,66h
      avx512_ptest_instruction:
	xor	cl,cl
	mov	[opcode_prefix],ah
	mov	[supplemental_code],al
	mov	al,38h
	or	[vex_required],8
	jmp	avx_cmp_common

mask_shift_instruction_q:
	or	[rex_prefix],8
mask_shift_instruction_d:
	or	[operand_flags],2
	or	[immediate_size],1
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	mov	al,3Ah
	jmp	mask_instruction
mask_instruction_single_source_b:
	mov	[opcode_prefix],66h
	jmp	mask_instruction_single_source_w
mask_instruction_single_source_d:
	mov	[opcode_prefix],66h
mask_instruction_single_source_q:
	or	[rex_prefix],8
mask_instruction_single_source_w:
	or	[operand_flags],2
	jmp	mask_instruction
mask_instruction_b:
	mov	[opcode_prefix],66h
	jmp	mask_instruction_w
mask_instruction_d:
	mov	[opcode_prefix],66h
mask_instruction_q:
	or	[rex_prefix],8
mask_instruction_w:
	mov	[operand_size],32
mask_instruction:
	or	[vex_required],1
	mov	[base_code],0Fh
	mov	[extended_code],al
	call	take_mask_register
	mov	[postbyte_register],al
	test	[operand_flags],2
	jnz	mask_instruction_nds_ok
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_mask_register
	mov	[vex_register],al
      mask_instruction_nds_ok:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_mask_register
	mov	bl,al
	cmp	[immediate_size],0
	jne	mmx_nomem_imm8
	jmp	nomem_instruction_ready
take_mask_register:
	lods	byte [esi]
	cmp	al,14h
	jne	invalid_operand
	lods	byte [esi]
convert_mask_register:
	mov	ah,al
	shr	ah,4
	cmp	ah,5
	jne	invalid_operand
	and	al,1111b
	ret
kmov_instruction:
	mov	[mmx_size],al
	or	[vex_required],1
	mov	[base_code],0Fh
	mov	[extended_code],90h
	lods	byte [esi]
	cmp	al,14h
	je	kmov_maskreg
	cmp	al,10h
	je	kmov_reg
	call	get_size_operator
	inc	[extended_code]
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_mask_register
	mov	[postbyte_register],al
      kmov_with_mem:
	mov	ah,[mmx_size]
	mov	al,[operand_size]
	or	al,al
	jz	kmov_mem_size_ok
	cmp	al,ah
	jne	invalid_operand_size
      kmov_mem_size_ok:
	call	setup_kmov_prefix
	jmp	instruction_ready
      setup_kmov_prefix:
	cmp	ah,4
	jb	kmov_w_ok
	or	[rex_prefix],8
      kmov_w_ok:
	test	ah,1 or 4
	jz	kmov_prefix_ok
	mov	[opcode_prefix],66h
      kmov_prefix_ok:
	ret
      kmov_maskreg:
	lods	byte [esi]
	call	convert_mask_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,14h
	je	kmov_maskreg_maskreg
	cmp	al,10h
	je	kmov_maskreg_reg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	jmp	kmov_with_mem
      kmov_maskreg_maskreg:
	lods	byte [esi]
	call	convert_mask_register
	mov	bl,al
	mov	ah,[mmx_size]
	call	setup_kmov_prefix
	jmp	nomem_instruction_ready
      kmov_maskreg_reg:
	add	[extended_code],2
	lods	byte [esi]
	call	convert_register
      kmov_with_reg:
	mov	bl,al
	mov	al,[mmx_size]
	mov	ah,4
	cmp	al,ah
	jbe	kmov_reg_size_check
	mov	ah,al
      kmov_reg_size_check:
	cmp	ah,[operand_size]
	jne	invalid_operand_size
	cmp	al,8
	je	kmov_f2_w1
	cmp	al,2
	ja	kmov_f2
	je	nomem_instruction_ready
	mov	[opcode_prefix],66h
	jmp	nomem_instruction_ready
      kmov_f2_w1:
	or	[rex_prefix],8
      kmov_f2:
	mov	[opcode_prefix],0F2h
	jmp	nomem_instruction_ready
      kmov_reg:
	add	[extended_code],3
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_mask_register
	jmp	kmov_with_reg
avx512_pmov_m2_instruction_w1:
	or	[rex_prefix],8
avx512_pmov_m2_instruction:
	or	[vex_required],8
	call	setup_f3_0f_38
	call	take_avx_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_mask_register
	mov	bl,al
	jmp	nomem_instruction_ready
avx512_pmov_2m_instruction_w1:
	or	[rex_prefix],8
avx512_pmov_2m_instruction:
	or	[vex_required],8
	call	setup_f3_0f_38
	call	take_mask_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	bl,al
	jmp	nomem_instruction_ready
      setup_f3_0f_38:
	mov	[extended_code],38h
	mov	[supplemental_code],al
	mov	[base_code],0Fh
	mov	[opcode_prefix],0F3h
	ret

vzeroall_instruction:
	mov	[operand_size],32
vzeroupper_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	and	[displacement_compression],0
	call	store_vex_instruction_code
	jmp	instruction_assembled
vldmxcsr_instruction:
	or	[vex_required],2
	jmp	fxsave_instruction

avx_perm2f128_instruction:
	or	[vex_required],2
	xor	ch,ch
      avx_instruction_imm8_without_128bit:
	mov	[immediate_size],1
	mov	ah,3Ah
	jmp	avx_instruction_without_128bit
avx512_shuf_q_instruction:
	or	[rex_prefix],8
	or	[vex_required],8
	mov	ch,8
	jmp	avx_instruction_imm8_without_128bit
avx512_shuf_d_instruction:
	or	[vex_required],8
	mov	ch,4
	jmp	avx_instruction_imm8_without_128bit
avx_permd_instruction:
	mov	ah,38h
	mov	ch,4
      avx_instruction_without_128bit:
	xor	cl,cl
	call	setup_avx_66_supplemental
	call	take_avx_register
	cmp	ah,32
	jb	invalid_operand_size
	mov	[postbyte_register],al
	call	take_avx512_mask
	jmp	avx_vex_reg
      setup_avx_66_supplemental:
	mov	[opcode_prefix],66h
	mov	[broadcast_size],ch
	mov	[mmx_size],cl
	mov	[base_code],0Fh
	mov	[extended_code],ah
	mov	[supplemental_code],al
	or	[vex_required],1
	ret
avx_permq_instruction:
	or	[rex_prefix],8
	mov	ch,8
	jmp	avx_permil_instruction
avx_permilpd_instruction:
	or	[rex_prefix],80h
	mov	ch,8
	jmp	avx_permil_instruction
avx_permilps_instruction:
	mov	ch,4
      avx_permil_instruction:
	or	[operand_flags],2
	xor	cl,cl
	mov	ah,3Ah
	call	setup_avx_66_supplemental
	call	take_avx_register
	cmp	[supplemental_code],4
	jae	avx_permil_size_ok
	cmp	ah,32
	jb	invalid_operand_size
      avx_permil_size_ok:
	mov	[postbyte_register],al
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_rm
	jnc	mmx_imm8
	mov	bl,al
	cmp	byte [esi],','
	jne	invalid_operand
	mov	al,[esi+1]
	cmp	al,11h
	jne	avx_permil_rm_or_imm8
	mov	al,[esi+3]
      avx_permil_rm_or_imm8:
	cmp	al,'('
	je	mmx_nomem_imm8
	mov	[vex_register],bl
	inc	esi
	mov	[extended_code],38h
	mov	al,[supplemental_code]
	cmp	al,4
	jb	avx_permq_rm
	add	[supplemental_code],8
	jmp	avx_regs_rm
      avx_permq_rm:
	or	[vex_required],8
	shl	al,5
	neg	al
	add	al,36h
	mov	[supplemental_code],al
	jmp	avx_regs_rm
vpermil_2pd_instruction:
	mov	[immediate_size],-2
	mov	byte [value],al
	mov	al,49h
	jmp	vpermil2_instruction_setup
vpermil_2ps_instruction:
	mov	[immediate_size],-2
	mov	byte [value],al
	mov	al,48h
	jmp	vpermil2_instruction_setup
vpermil2_instruction:
	mov	[immediate_size],-3
	mov	byte [value],0
      vpermil2_instruction_setup:
	or	[vex_required],2
	mov	[base_code],0Fh
	mov	[supplemental_code],al
	mov	al,3Ah
	xor	cl,cl
	jmp	avx_instruction

avx_shift_q_instruction_evex:
	or	[vex_required],8
avx_shift_q_instruction:
	or	[rex_prefix],80h
	mov	cl,8
	jmp	avx_shift_instruction
avx_shift_d_instruction:
	mov	cl,4
	jmp	avx_shift_instruction
avx_shift_bw_instruction:
	xor	cl,cl
       avx_shift_instruction:
	mov	[broadcast_size],cl
	mov	[mmx_size],0
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	call	take_avx_register
	mov	[postbyte_register],al
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	cl,cl
	xchg	cl,[operand_size]
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	avx_shift_reg_mem
	mov	[operand_size],cl
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_avx_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	push	esi
	xor	cl,cl
	xchg	cl,[operand_size]
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_shift_reg_reg_reg
	pop	esi
	cmp	al,'['
	je	avx_shift_reg_reg_mem
	xchg	cl,[operand_size]
	test	cl,not 1
	jnz	invalid_operand_size
	dec	esi
	call	convert_avx_shift_opcode
	mov	bl,al
	jmp	mmx_nomem_imm8
      convert_avx_shift_opcode:
	mov	al,[extended_code]
	mov	ah,al
	and	ah,1111b
	add	ah,70h
	mov	[extended_code],ah
	shr	al,4
	sub	al,0Ch
	shl	al,1
	xchg	al,[postbyte_register]
	xchg	al,[vex_register]
	ret
      avx_shift_reg_reg_reg:
	pop	eax
	lods	byte [esi]
	call	convert_xmm_register
	xchg	cl,[operand_size]
	mov	bl,al
	jmp	nomem_instruction_ready
      avx_shift_reg_reg_mem:
	mov	[mmx_size],16
	push	ecx
	lods	byte [esi]
	call	get_size_operator
	call	get_address
	pop	eax
	xchg	al,[operand_size]
	test	al,al
	jz	instruction_ready
	cmp	al,16
	jne	invalid_operand_size
	jmp	instruction_ready
      avx_shift_reg_mem:
	or	[vex_required],8
	call	take_avx_mem
	call	convert_avx_shift_opcode
	jmp	mmx_imm8
avx_shift_dq_instruction:
	mov	[postbyte_register],al
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],73h
	or	[vex_required],1
	mov	[mmx_size],0
	call	take_avx_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	avx_shift_dq_reg_mem
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_avx_register
	mov	bl,al
	jmp	mmx_nomem_imm8
      avx_shift_dq_reg_mem:
	or	[vex_required],8
	call	get_address
	jmp	mmx_imm8
avx512_rotate_q_instruction:
	mov	cl,8
	or	[rex_prefix],cl
	jmp	avx512_rotate_instruction
avx512_rotate_d_instruction:
	mov	cl,4
      avx512_rotate_instruction:
	mov	[broadcast_size],cl
	mov	[postbyte_register],al
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],72h
	or	[vex_required],8
	mov	[mmx_size],0
	mov	[immediate_size],1
	call	take_avx_register
	mov	[vex_register],al
	call	take_avx512_mask
	jmp	avx_vex_reg_ok

avx_pmovsxbq_instruction:
	mov	cl,2
	jmp	avx_pmovsx_instruction
avx_pmovsxbd_instruction:
	mov	cl,4
	jmp	avx_pmovsx_instruction
avx_pmovsxbw_instruction:
	mov	cl,8
      avx_pmovsx_instruction:
	mov	[mmx_size],cl
	or	[vex_required],1
	call	setup_66_0f_38
	call	take_avx_register
	mov	[postbyte_register],al
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	al,al
	xchg	al,[operand_size]
	bsf	ecx,eax
	sub	cl,4
	shl	[mmx_size],cl
	push	eax
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_pmovsx_reg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop	eax
	xchg	al,[operand_size]
	or	al,al
	jz	instruction_ready
	cmp	al,[mmx_size]
	jne	invalid_operand_size
	jmp	instruction_ready
      avx_pmovsx_reg_reg:
	lods	byte [esi]
	call	convert_avx_register
	mov	bl,al
	cmp	ah,[mmx_size]
	je	avx_pmovsx_xmmreg_reg_size_ok
	jb	invalid_operand_size
	cmp	ah,16
	jne	invalid_operand_size
      avx_pmovsx_xmmreg_reg_size_ok:
	pop	eax
	mov	[operand_size],al
	jmp	nomem_instruction_ready
avx512_pmovqb_instruction:
	mov	cl,2
	jmp	avx512_pmov_instruction
avx512_pmovdb_instruction:
	mov	cl,4
	jmp	avx512_pmov_instruction
avx512_pmovwb_instruction:
	mov	cl,8
      avx512_pmov_instruction:
	mov	[mmx_size],cl
	or	[vex_required],8
	mov	[extended_code],38h
	mov	[supplemental_code],al
	mov	[base_code],0Fh
	mov	[opcode_prefix],0F3h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx512_pmov_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	[operand_flags],20h
	call	avx512_pmov_common
	or	al,al
	jz	instruction_ready
	cmp	al,[mmx_size]
	jne	invalid_operand_size
	jmp	instruction_ready
      avx512_pmov_common:
	call	take_avx512_mask
	xor	al,al
	xchg	al,[operand_size]
	push	eax
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[postbyte_register],al
	mov	al,ah
	mov	ah,cl
	bsf	ecx,eax
	sub	cl,4
	shl	[mmx_size],cl
	mov	cl,ah
	pop	eax
	ret
      avx512_pmov_reg:
	lods	byte [esi]
	call	convert_avx_register
	mov	bl,al
	call	avx512_pmov_common
	cmp	al,[mmx_size]
	je	nomem_instruction_ready
	jb	invalid_operand_size
	cmp	al,16
	jne	invalid_operand_size
	jmp	nomem_instruction_ready

avx_broadcast_128_instruction_noevex:
	or	[vex_required],2
	mov	cl,10h
	jmp	avx_broadcast_instruction
avx512_broadcast_32x2_instruction:
	mov	cl,08h
	jmp	avx_broadcast_instruction_evex
avx512_broadcast_32x4_instruction:
	mov	cl,10h
	jmp	avx_broadcast_instruction_evex
avx512_broadcast_32x8_instruction:
	mov	cl,20h
	jmp	avx_broadcast_instruction_evex
avx512_broadcast_64x2_instruction:
	mov	cl,10h
	jmp	avx_broadcast_instruction_w1_evex
avx512_broadcast_64x4_instruction:
	mov	cl,20h
      avx_broadcast_instruction_w1_evex:
	or	[rex_prefix],8
      avx_broadcast_instruction_evex:
	or	[vex_required],8
	jmp	avx_broadcast_instruction
avx_broadcastss_instruction:
	mov	cl,4
	jmp	avx_broadcast_instruction
avx_broadcastsd_instruction:
	or	[rex_prefix],80h
	mov	cl,8
	jmp	avx_broadcast_instruction
avx_pbroadcastb_instruction:
	mov	cl,1
	jmp	avx_broadcast_pi_instruction
avx_pbroadcastw_instruction:
	mov	cl,2
	jmp	avx_broadcast_pi_instruction
avx_pbroadcastd_instruction:
	mov	cl,4
	jmp	avx_broadcast_pi_instruction
avx_pbroadcastq_instruction:
	mov	cl,8
	or	[rex_prefix],80h
      avx_broadcast_pi_instruction:
	or	[operand_flags],40h
      avx_broadcast_instruction:
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	mov	al,38h
	mov	[mmx_size],cl
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	call	take_avx_register
	cmp	ah,[mmx_size]
	je	invalid_operand_size
	test	[operand_flags],40h
	jnz	avx_broadcast_destination_size_ok
	cmp	[mmx_size],4
	je	avx_broadcast_destination_size_ok
	cmp	[supplemental_code],59h
	je	avx_broadcast_destination_size_ok
	cmp	ah,16
	je	invalid_operand_size
      avx_broadcast_destination_size_ok:
	xor	ah,ah
	xchg	ah,[operand_size]
	push	eax
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_broadcast_reg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop	eax
	xchg	ah,[operand_size]
	mov	[postbyte_register],al
	mov	al,[broadcast_size]
	mov	al,[mmx_size]
	cmp	al,ah
	je	instruction_ready
	or	al,al
	jz	instruction_ready
	or	ah,ah
	jz	instruction_ready
	jmp	invalid_operand_size
      avx_broadcast_reg_reg:
	lods	byte [esi]
	test	[operand_flags],40h
	jz	avx_broadcast_reg_avx_reg
	cmp	al,60h
	jb	avx_broadcast_reg_general_reg
	cmp	al,80h
	jb	avx_broadcast_reg_avx_reg
	cmp	al,0C0h
	jb	avx_broadcast_reg_general_reg
      avx_broadcast_reg_avx_reg:
	call	convert_avx_register
	mov	bl,al
	mov	al,[mmx_size]
	or	al,al
	jz	avx_broadcast_reg_avx_reg_size_ok
	cmp	ah,16
	jne	invalid_operand_size
	cmp	al,ah
	jae	invalid_operand
      avx_broadcast_reg_avx_reg_size_ok:
	pop	eax
	xchg	ah,[operand_size]
	mov	[postbyte_register],al
	test	[vex_required],2
	jnz	invalid_operand
	jmp	nomem_instruction_ready
      avx_broadcast_reg_general_reg:
	call	convert_register
	mov	bl,al
	mov	al,[mmx_size]
	or	al,al
	jz	avx_broadcast_reg_general_reg_size_ok
	cmp	al,ah
	jne	invalid_operand_size
      avx_broadcast_reg_general_reg_size_ok:
	cmp	al,4
	jb	avx_broadcast_reg_general_reg_ready
	cmp	al,8
	mov	al,3
	jne	avx_broadcast_reg_general_reg_ready
	or	[rex_prefix],8
      avx_broadcast_reg_general_reg_ready:
	add	al,7Ah-1
	mov	[supplemental_code],al
	or	[vex_required],8
	pop	eax
	xchg	ah,[operand_size]
	mov	[postbyte_register],al
	jmp	nomem_instruction_ready

avx512_extract_64x4_instruction:
	or	[rex_prefix],8
avx512_extract_32x8_instruction:
	or	[vex_required],8
	mov	cl,32
	jmp	avx_extractf_instruction
avx512_extract_64x2_instruction:
	or	[rex_prefix],8
avx512_extract_32x4_instruction:
	or	[vex_required],8
	mov	cl,16
	jmp	avx_extractf_instruction
avx_extractf128_instruction:
	or	[vex_required],2
	mov	cl,16
      avx_extractf_instruction:
	mov	[mmx_size],cl
	call	setup_66_0f_3a
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_extractf_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	xor	al,al
	xchg	al,[operand_size]
	or	al,al
	jz	avx_extractf_mem_size_ok
	cmp	al,[mmx_size]
	jne	invalid_operand_size
      avx_extractf_mem_size_ok:
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	cmp	ah,[mmx_size]
	jbe	invalid_operand_size
	mov	[postbyte_register],al
	jmp	mmx_imm8
      avx_extractf_reg:
	lods	byte [esi]
	call	convert_avx_register
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	push	eax
	call	take_avx512_mask
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	cmp	ah,[mmx_size]
	jbe	invalid_operand_size
	mov	[postbyte_register],al
	pop	ebx
	jmp	mmx_nomem_imm8
avx512_insert_64x4_instruction:
	or	[rex_prefix],8
avx512_insert_32x8_instruction:
	or	[vex_required],8
	mov	cl,32
	jmp	avx_insertf_instruction
avx512_insert_64x2_instruction:
	or	[rex_prefix],8
avx512_insert_32x4_instruction:
	or	[vex_required],8
	mov	cl,16
	jmp	avx_insertf_instruction
avx_insertf128_instruction:
	or	[vex_required],2
	mov	cl,16
      avx_insertf_instruction:
	mov	[mmx_size],cl
	mov	[broadcast_size],0
	call	setup_66_0f_3a
	call	take_avx_register
	cmp	ah,[mmx_size]
	jbe	invalid_operand
	mov	[postbyte_register],al
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[vex_register],al
	mov	al,[mmx_size]
	xchg	al,[operand_size]
	push	eax
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_insertf_reg_reg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop	eax
	mov	[operand_size],al
	jmp	mmx_imm8
      avx_insertf_reg_reg_reg:
	lods	byte [esi]
	call	convert_avx_register
	mov	bl,al
	pop	eax
	mov	[operand_size],al
	jmp	mmx_nomem_imm8
avx_extract_b_instruction:
	mov	cl,1
	jmp	avx_extract_instruction
avx_extract_w_instruction:
	mov	cl,2
	jmp	avx_extract_instruction
avx_extract_q_instruction:
	or	[rex_prefix],8
	mov	cl,8
	jmp	avx_extract_instruction
avx_extract_d_instruction:
	mov	cl,4
      avx_extract_instruction:
	mov	[mmx_size],cl
	call	setup_66_0f_3a
	or	[vex_required],1
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	avx_extractps_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[mmx_size]
	not	al
	and	[operand_size],al
	jnz	invalid_operand_size
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_avx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	jmp	mmx_imm8
      avx_extractps_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	mov	al,[mmx_size]
	cmp	ah,al
	jb	invalid_operand_size
	cmp	ah,4
	je	avx_extractps_reg_size_ok
	cmp	ah,8
	jne	invalid_operand_size
	cmp	[code_type],64
	jne	invalid_operand
	cmp	al,4
	ja	avx_extractps_reg_size_ok
	je	invalid_operand_size
	or	[rex_prefix],8
      avx_extractps_reg_size_ok:
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_avx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	cmp	[supplemental_code],15h
	jne	mmx_nomem_imm8
	mov	[extended_code],0C5h
	xchg	bl,[postbyte_register]
	jmp	mmx_nomem_imm8
avx_insertps_instruction:
	mov	[immediate_size],1
	or	[operand_flags],10h
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	mov	al,3Ah
	mov	cl,4
	jmp	avx_instruction
avx_pinsrb_instruction:
	mov	cl,1
	jmp	avx_pinsr_instruction_3a
avx_pinsrw_instruction:
	mov	cl,2
	jmp	avx_pinsr_instruction
avx_pinsrd_instruction:
	mov	cl,4
	jmp	avx_pinsr_instruction_3a
avx_pinsrq_instruction:
	mov	cl,8
	or	[rex_prefix],8
      avx_pinsr_instruction_3a:
	mov	[supplemental_code],al
	mov	al,3Ah
      avx_pinsr_instruction:
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],cl
	or	[vex_required],1
	call	take_avx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[vex_register],al
	jmp	pinsr_xmmreg

avx_cvtudq2pd_instruction:
	or	[vex_required],8
avx_cvtdq2pd_instruction:
	mov	[opcode_prefix],0F3h
	mov	cl,4
	jmp	avx_cvt_d_instruction
avx_cvtps2qq_instruction:
	or	[operand_flags],8
avx_cvttps2qq_instruction:
	or	[operand_flags],4
	or	[vex_required],8
	mov	[opcode_prefix],66h
	mov	cl,4
	jmp	avx_cvt_d_instruction
avx_cvtps2pd_instruction:
	or	[operand_flags],4
	mov	cl,4
      avx_cvt_d_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	mov	[broadcast_size],cl
	call	take_avx_register
	mov	[postbyte_register],al
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	ecx,ecx
	xchg	cl,[operand_size]
	mov	al,cl
	shr	al,1
	mov	[mmx_size],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	avx_cvt_d_reg_mem
	cmp	al,10h
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	convert_avx_register
	cmp	ah,[mmx_size]
	je	avx_cvt_d_reg_reg_size_ok
	jb	invalid_operand_size
	cmp	ah,16
	jne	invalid_operand_size
      avx_cvt_d_reg_reg_size_ok:
	mov	bl,al
	mov	[operand_size],cl
	call	take_avx512_rounding
	jmp	nomem_instruction_ready
      avx_cvt_d_reg_mem:
	call	take_avx_mem
	jmp	instruction_ready
avx_cvtpd2dq_instruction:
	or	[operand_flags],4+8
	mov	[opcode_prefix],0F2h
	jmp	avx_cvt_q_instruction
avx_cvtuqq2ps_instruction:
	mov	[opcode_prefix],0F2h
avx_cvtpd2udq_instruction:
	or	[operand_flags],8
avx_cvttpd2udq_instruction:
	or	[operand_flags],4
	or	[vex_required],8
	jmp	avx_cvt_q_instruction
avx_cvtpd2ps_instruction:
	or	[operand_flags],8
avx_cvttpd2dq_instruction:
	or	[operand_flags],4
	mov	[opcode_prefix],66h
      avx_cvt_q_instruction:
	mov	[broadcast_size],8
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	or	[rex_prefix],80h
	call	take_avx_register
	mov	[postbyte_register],al
	push	eax
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	al,al
	mov	[operand_size],al
	mov	[mmx_size],al
	call	take_avx_rm
	jnc	avx_cvt_q_reg_mem
	mov	bl,al
	pop	eax
	call	avx_cvt_q_check_size
	call	take_avx512_rounding
	jmp	nomem_instruction_ready
      avx_cvt_q_reg_mem:
	pop	eax
	call	avx_cvt_q_check_size
	jmp	instruction_ready
      avx_cvt_q_check_size:
	mov	al,[operand_size]
	or	al,al
	jz	avx_cvt_q_size_not_specified
	shr	al,1
	cmp	al,ah
	je	avx_cvt_q_size_ok
	ja	invalid_operand_size
	cmp	ah,16
	jne	invalid_operand_size
      avx_cvt_q_size_ok:
	ret
      avx_cvt_q_size_not_specified:
	cmp	ah,64 shr 1
	jne	operand_size_not_specified
	mov	[operand_size],64
	ret
avx_cvttps2udq_instruction:
	or	[vex_required],8
	or	[operand_flags],2+4
	mov	cx,0400h
	jmp	avx_instruction_with_broadcast
avx_cvttps2dq_instruction:
	mov	[opcode_prefix],0F3h
	or	[operand_flags],2+4
	mov	cx,0400h
	jmp	avx_instruction_with_broadcast
avx_cvtph2ps_instruction:
	mov	[opcode_prefix],66h
	mov	[supplemental_code],al
	or	[operand_flags],4
	mov	al,38h
	xor	cl,cl
	jmp	avx_cvt_d_instruction
avx_cvtps2ph_instruction:
	call	setup_66_0f_3a
	or	[vex_required],1
	or	[operand_flags],4
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	vcvtps2ph_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	shl	[operand_size],1
	call	take_avx_register
	mov	[postbyte_register],al
	shr	ah,1
	mov	[mmx_size],ah
	jmp	mmx_imm8
      vcvtps2ph_reg:
	lods	byte [esi]
	call	convert_avx_register
	mov	bl,al
	call	take_avx512_mask
	xor	cl,cl
	xchg	cl,[operand_size]
	shl	cl,1
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[postbyte_register],al
	or	cl,cl
	jz	vcvtps2ph_reg_size_ok
	cmp	cl,ah
	je	vcvtps2ph_reg_size_ok
	jb	invalid_operand_size
	cmp	ah,16
	jne	invalid_operand_size
      vcvtps2ph_reg_size_ok:
	call	take_avx512_rounding
	jmp	mmx_nomem_imm8

avx_cvtsd2usi_instruction:
	or	[operand_flags],8
avx_cvttsd2usi_instruction:
	or	[vex_required],8
	jmp	avx_cvttsd2si_instruction
avx_cvtsd2si_instruction:
	or	[operand_flags],8
avx_cvttsd2si_instruction:
	mov	ah,0F2h
	mov	cl,8
	jmp	avx_cvt_2si_instruction
avx_cvtss2usi_instruction:
	or	[operand_flags],8
avx_cvttss2usi_instruction:
	or	[vex_required],8
	jmp	avx_cvttss2si_instruction
avx_cvtss2si_instruction:
	or	[operand_flags],8
avx_cvttss2si_instruction:
	mov	ah,0F3h
	mov	cl,4
      avx_cvt_2si_instruction:
	or	[operand_flags],2+4
	mov	[mmx_size],cl
	mov	[broadcast_size],0
	mov	[opcode_prefix],ah
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	mov	[operand_size],0
	cmp	ah,4
	je	avx_cvt_2si_reg
	cmp	ah,8
	jne	invalid_operand_size
	call	operand_64bit
      avx_cvt_2si_reg:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_rm
	jnc	instruction_ready
	mov	bl,al
	call	take_avx512_rounding
	jmp	nomem_instruction_ready
avx_cvtusi2sd_instruction:
	or	[vex_required],8
avx_cvtsi2sd_instruction:
	mov	ah,0F2h
	mov	cl,8
	jmp	avx_cvtsi_instruction
avx_cvtusi2ss_instruction:
	or	[vex_required],8
avx_cvtsi2ss_instruction:
	mov	ah,0F3h
	mov	cl,4
      avx_cvtsi_instruction:
	or	[operand_flags],2+4+8
	mov	[mmx_size],cl
	mov	[opcode_prefix],ah
	mov	[base_code],0Fh
	mov	[extended_code],al
	or	[vex_required],1
	call	take_avx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	avx_cvtsi_reg_reg_mem
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	cmp	ah,4
	je	avx_cvtsi_reg_reg_reg32
	cmp	ah,8
	jne	invalid_operand_size
	call	operand_64bit
      avx_cvtsi_rounding:
	call	take_avx512_rounding
	jmp	nomem_instruction_ready
      avx_cvtsi_reg_reg_reg32:
	cmp	[mmx_size],8
	jne	avx_cvtsi_rounding
	jmp	nomem_instruction_ready
      avx_cvtsi_reg_reg_mem:
	call	get_address
	mov	al,[operand_size]
	mov	[mmx_size],al
	cmp	al,4
	je	instruction_ready
	cmp	al,8
	jne	invalid_operand_size
	call	operand_64bit
	jmp	instruction_ready

avx_maskmov_w1_instruction:
	or	[rex_prefix],8
avx_maskmov_instruction:
	call	setup_66_0f_38
	mov	[mmx_size],0
	or	[vex_required],2
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	avx_maskmov_mem
	lods	byte [esi]
	call	convert_avx_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	jmp	instruction_ready
      avx_maskmov_mem:
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	[postbyte_register],al
	add	[supplemental_code],2
	jmp	instruction_ready
avx_movmskpd_instruction:
	mov	[opcode_prefix],66h
avx_movmskps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],50h
	or	[vex_required],2
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	cmp	ah,4
	je	avx_movmskps_reg_ok
	cmp	ah,8
	jne	invalid_operand_size
	cmp	[code_type],64
	jne	invalid_operand
      avx_movmskps_reg_ok:
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	bl,al
	jmp	nomem_instruction_ready
avx_maskmovdqu_instruction:
	or	[vex_required],2
	jmp	maskmovdqu_instruction
avx_pmovmskb_instruction:
	or	[vex_required],2
	mov	[opcode_prefix],66h
	mov	[base_code],0Fh
	mov	[extended_code],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	cmp	ah,4
	je	avx_pmovmskb_reg_size_ok
	cmp	[code_type],64
	jne	invalid_operand_size
	cmp	ah,8
	jnz	invalid_operand_size
      avx_pmovmskb_reg_size_ok:
	mov	[postbyte_register],al
	mov	[operand_size],0
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	call	take_avx_register
	mov	bl,al
	jmp	nomem_instruction_ready

gather_pd_instruction:
	or	[rex_prefix],8
gather_ps_instruction:
	call	setup_66_0f_38
	or	[vex_required],4
	or	[operand_flags],20h
	call	take_avx_register
	mov	[postbyte_register],al
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	cl,cl
	xchg	cl,[operand_size]
	push	ecx
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	pop	eax
	xchg	al,[operand_size]
      gather_mem_size_check:
	mov	ah,4
	test	[rex_prefix],8
	jz	gather_elements_size_ok
	add	ah,ah
      gather_elements_size_ok:
	mov	[mmx_size],ah
	test	al,al
	jz	gather_mem_size_ok
	cmp	al,ah
	jne	invalid_operand_size
      gather_mem_size_ok:
	cmp	byte [esi],','
	je	gather_reg_mem_reg
	test	[vex_required],20h
	jz	invalid_operand
	mov	ah,[operand_size]
	mov	al,80h
	jmp	gather_arguments_ok
      gather_reg_mem_reg:
	or	[vex_required],2
	inc	esi
	call	take_avx_register
      gather_arguments_ok:
	mov	[vex_register],al
	cmp	al,[postbyte_register]
	je	disallowed_combination_of_registers
	mov	al,bl
	and	al,11111b
	cmp	al,[postbyte_register]
	je	disallowed_combination_of_registers
	cmp	al,[vex_register]
	je	disallowed_combination_of_registers
	mov	al,bl
	shr	al,5
	cmp	al,0Ch shr 1
	je	gather_vr128
	mov	ah,32
	cmp	al,6 shr 1
	jne	gather_regular
	add	ah,ah
      gather_regular:
	mov	al,[rex_prefix]
	shr	al,3
	xor	al,[supplemental_code]
	test	al,1
	jz	gather_uniform
	test	[supplemental_code],1
	jz	gather_double
	mov	al,ah
	xchg	al,[operand_size]
	add	al,al
	cmp	al,ah
	jne	invalid_operand_size
	jmp	instruction_ready
      gather_double:
	add	ah,ah
      gather_uniform:
	cmp	ah,[operand_size]
	jne	invalid_operand_size
	jmp	instruction_ready
      gather_vr128:
	cmp	ah,16
	je	instruction_ready
	cmp	ah,32
	jne	invalid_operand_size
	test	[supplemental_code],1
	jnz	invalid_operand_size
	test	[rex_prefix],8
	jz	invalid_operand_size
	jmp	instruction_ready
scatter_pd_instruction:
	or	[rex_prefix],8
scatter_ps_instruction:
	call	setup_66_0f_38
	or	[vex_required],4+8
	or	[operand_flags],20h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	call	take_avx512_mask
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	al,al
	xchg	al,[operand_size]
	push	eax
	call	take_avx_register
	mov	[postbyte_register],al
	pop	eax
	jmp	gather_mem_size_check
gatherpf_qpd_instruction:
	mov	ah,0C7h
	jmp	gatherpf_pd_instruction
gatherpf_dpd_instruction:
	mov	ah,0C6h
      gatherpf_pd_instruction:
	or	[rex_prefix],8
	mov	cl,8
	jmp	gatherpf_instruction
gatherpf_qps_instruction:
	mov	ah,0C7h
	jmp	gatherpf_ps_instruction
gatherpf_dps_instruction:
	mov	ah,0C6h
      gatherpf_ps_instruction:
	mov	cl,4
      gatherpf_instruction:
	mov	[mmx_size],cl
	mov	[postbyte_register],al
	mov	al,ah
	call	setup_66_0f_38
	or	[vex_required],4+8
	or	[operand_flags],20h
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	call	take_avx512_mask
	mov	ah,[mmx_size]
	mov	al,[operand_size]
	or	al,al
	jz	gatherpf_mem_size_ok
	cmp	al,ah
	jne	invalid_operand_size
      gatherpf_mem_size_ok:
	mov	[operand_size],64
	mov	al,6 shr 1
	cmp	ah,4
	je	gatherpf_check_vsib
	cmp	[supplemental_code],0C6h
	jne	gatherpf_check_vsib
	mov	al,0Eh shr 1
      gatherpf_check_vsib:
	mov	ah,bl
	shr	ah,5
	cmp	al,ah
	jne	invalid_operand
	jmp	instruction_ready

bmi_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],38h
	mov	[supplemental_code],0F3h
	mov	[postbyte_register],al
      bmi_reg:
	or	[vex_required],2
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	bmi_reg_reg
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	call	operand_32or64
	jmp	instruction_ready
      bmi_reg_reg:
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	call	operand_32or64
	jmp	nomem_instruction_ready
      operand_32or64:
	mov	al,[operand_size]
	cmp	al,4
	je	operand_32or64_ok
	cmp	al,8
	jne	invalid_operand_size
	cmp	[code_type],64
	jne	invalid_operand
	or	[rex_prefix],8
      operand_32or64_ok:
	ret
pdep_instruction:
	mov	[opcode_prefix],0F2h
	jmp	andn_instruction
pext_instruction:
	mov	[opcode_prefix],0F3h
andn_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],38h
	mov	[supplemental_code],al
	or	[vex_required],2
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	jmp	bmi_reg
sarx_instruction:
	mov	[opcode_prefix],0F3h
	jmp	bzhi_instruction
shrx_instruction:
	mov	[opcode_prefix],0F2h
	jmp	bzhi_instruction
shlx_instruction:
	mov	[opcode_prefix],66h
bzhi_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],38h
	mov	[supplemental_code],al
	or	[vex_required],2
	call	get_reg_mem
	jc	bzhi_reg_reg
	call	get_vex_source_register
	jc	invalid_operand
	call	operand_32or64
	jmp	instruction_ready
      bzhi_reg_reg:
	call	get_vex_source_register
	jc	invalid_operand
	call	operand_32or64
	jmp	nomem_instruction_ready
      get_vex_source_register:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	no_vex_source_register
	lods	byte [esi]
	call	convert_register
	mov	[vex_register],al
	clc
	ret
      no_vex_source_register:
	stc
	ret
bextr_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],38h
	mov	[supplemental_code],al
	or	[vex_required],2
	call	get_reg_mem
	jc	bextr_reg_reg
	call	get_vex_source_register
	jc	bextr_reg_mem_imm32
	call	operand_32or64
	jmp	instruction_ready
      bextr_reg_reg:
	call	get_vex_source_register
	jc	bextr_reg_reg_imm32
	call	operand_32or64
	jmp	nomem_instruction_ready
      setup_bextr_imm_opcode:
	mov	[xop_opcode_map],0Ah
	mov	[base_code],10h
	call	operand_32or64
	ret
      bextr_reg_mem_imm32:
	call	get_imm32
	call	setup_bextr_imm_opcode
	jmp	store_instruction_with_imm32
      bextr_reg_reg_imm32:
	call	get_imm32
	call	setup_bextr_imm_opcode
      store_nomem_instruction_with_imm32:
	call	store_nomem_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stos	dword [edi]
	jmp	instruction_assembled
      get_imm32:
	cmp	al,'('
	jne	invalid_operand
	push	edx ebx ecx
	call	get_dword_value
	mov	dword [value],eax
	pop	ecx ebx edx
	ret
rorx_instruction:
	mov	[opcode_prefix],0F2h
	mov	[base_code],0Fh
	mov	[extended_code],3Ah
	mov	[supplemental_code],al
	or	[vex_required],2
	call	get_reg_mem
	jc	rorx_reg_reg
	call	operand_32or64
	jmp	mmx_imm8
      rorx_reg_reg:
	call	operand_32or64
	jmp	mmx_nomem_imm8

tbm_instruction:
	mov	[xop_opcode_map],9
	mov	ah,al
	shr	ah,4
	and	al,111b
	mov	[base_code],ah
	mov	[postbyte_register],al
	jmp	bmi_reg

llwpcb_instruction:
	or	[vex_required],2
	mov	[xop_opcode_map],9
	mov	[base_code],12h
	mov	[postbyte_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	bl,al
	call	operand_32or64
	jmp	nomem_instruction_ready
lwpins_instruction:
	or	[vex_required],2
	mov	[xop_opcode_map],0Ah
	mov	[base_code],12h
	mov	[vex_register],al
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_register
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	xor	cl,cl
	xchg	cl,[operand_size]
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	je	lwpins_reg_reg
	cmp	al,'['
	jne	invalid_argument
	push	ecx
	call	get_address
	pop	eax
	xchg	al,[operand_size]
	test	al,al
	jz	lwpins_reg_mem_size_ok
	cmp	al,4
	jne	invalid_operand_size
      lwpins_reg_mem_size_ok:
	call	prepare_lwpins
	jmp	store_instruction_with_imm32
      lwpins_reg_reg:
	lods	byte [esi]
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	[operand_size],cl
	mov	bl,al
	call	prepare_lwpins
	jmp	store_nomem_instruction_with_imm32
      prepare_lwpins:
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_imm32
	call	operand_32or64
	mov	al,[vex_register]
	xchg	al,[postbyte_register]
	mov	[vex_register],al
	ret

xop_single_source_sd_instruction:
	or	[operand_flags],2
	mov	[mmx_size],8
	jmp	xop_instruction_9
xop_single_source_ss_instruction:
	or	[operand_flags],2
	mov	[mmx_size],4
	jmp	xop_instruction_9
xop_single_source_instruction:
	or	[operand_flags],2
	mov	[mmx_size],0
      xop_instruction_9:
	mov	[base_code],al
	mov	[xop_opcode_map],9
	jmp	avx_xop_common
xop_single_source_128bit_instruction:
	or	[operand_flags],2
	mov	[mmx_size],16
	jmp	xop_instruction_9
xop_triple_source_128bit_instruction:
	mov	[immediate_size],-1
	mov	byte [value],0
	mov	[mmx_size],16
	jmp	xop_instruction_8
xop_128bit_instruction:
	mov	[immediate_size],-2
	mov	byte [value],0
	mov	[mmx_size],16
      xop_instruction_8:
	mov	[base_code],al
	mov	[xop_opcode_map],8
	jmp	avx_xop_common
xop_pcom_b_instruction:
	mov	ah,0CCh
	jmp	xop_pcom_instruction
xop_pcom_d_instruction:
	mov	ah,0CEh
	jmp	xop_pcom_instruction
xop_pcom_q_instruction:
	mov	ah,0CFh
	jmp	xop_pcom_instruction
xop_pcom_w_instruction:
	mov	ah,0CDh
	jmp	xop_pcom_instruction
xop_pcom_ub_instruction:
	mov	ah,0ECh
	jmp	xop_pcom_instruction
xop_pcom_ud_instruction:
	mov	ah,0EEh
	jmp	xop_pcom_instruction
xop_pcom_uq_instruction:
	mov	ah,0EFh
	jmp	xop_pcom_instruction
xop_pcom_uw_instruction:
	mov	ah,0EDh
      xop_pcom_instruction:
	mov	byte [value],al
	mov	[immediate_size],-4
	mov	[mmx_size],16
	mov	[base_code],ah
	mov	[xop_opcode_map],8
	jmp	avx_xop_common
vpcmov_instruction:
	or	[vex_required],2
	mov	[immediate_size],-2
	mov	byte [value],0
	mov	[mmx_size],0
	mov	[base_code],al
	mov	[xop_opcode_map],8
	jmp	avx_xop_common
xop_shift_instruction:
	mov	[base_code],al
	or	[vex_required],2
	mov	[xop_opcode_map],9
	call	take_avx_register
	cmp	ah,16
	jne	invalid_operand
	mov	[postbyte_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	lods	byte [esi]
	call	get_size_operator
	cmp	al,'['
	je	xop_shift_reg_mem
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
	call	convert_xmm_register
	mov	[vex_register],al
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	push	esi
	xor	cl,cl
	xchg	cl,[operand_size]
	lods	byte [esi]
	call	get_size_operator
	pop	esi
	xchg	cl,[operand_size]
	cmp	al,'['
	je	xop_shift_reg_reg_mem
	cmp	al,10h
	jne	xop_shift_reg_reg_imm
	call	take_avx_register
	mov	bl,al
	xchg	bl,[vex_register]
	jmp	nomem_instruction_ready
      xop_shift_reg_reg_mem:
	or	[rex_prefix],8
	lods	byte [esi]
	call	get_size_operator
	call	get_address
	jmp	instruction_ready
      xop_shift_reg_reg_imm:
	xor	bl,bl
	xchg	bl,[vex_register]
	cmp	[base_code],94h
	jae	invalid_operand
	add	[base_code],30h
	mov	[xop_opcode_map],8
	dec	esi
	jmp	mmx_nomem_imm8
      xop_shift_reg_mem:
	call	get_address
	lods	byte [esi]
	cmp	al,','
	jne	invalid_operand
	push	esi
	xor	cl,cl
	xchg	cl,[operand_size]
	lods	byte [esi]
	call	get_size_operator
	pop	esi
	xchg	cl,[operand_size]
	cmp	al,10h
	jne	xop_shift_reg_mem_imm
	call	take_avx_register
	mov	[vex_register],al
	jmp	instruction_ready
      xop_shift_reg_mem_imm:
	cmp	[base_code],94h
	jae	invalid_operand
	add	[base_code],30h
	mov	[xop_opcode_map],8
	dec	esi
	jmp	mmx_imm8

set_evex_mode:
	mov	[evex_mode],al
	jmp	instruction_assembled

take_avx_register:
	lods	byte [esi]
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lods	byte [esi]
convert_avx_register:
	mov	ah,al
	and	al,1Fh
	and	ah,0E0h
	sub	ah,60h
	jb	invalid_operand
	jz	avx512_register_size
	sub	ah,60h
	jb	invalid_operand
	jnz	avx_register_size_ok
	mov	ah,16
	jmp	avx_register_size_ok
      avx512_register_size:
	mov	ah,64
      avx_register_size_ok:
	cmp	al,8
	jb	match_register_size
	cmp	[code_type],64
	jne	invalid_operand
	jmp	match_register_size
store_vex_instruction_code:
	test	[rex_prefix],10h
	jnz	invalid_operand
	test	[vex_required],0F8h
	jnz	store_evex_instruction_code
	test	[vex_register],10000b
	jnz	store_evex_instruction_code
	cmp	[operand_size],64
	je	store_evex_instruction_code
	mov	al,[base_code]
	cmp	al,0Fh
	jne	store_xop_instruction_code
	test	[vex_required],2
	jnz	prepare_vex
	cmp	[evex_mode],0
	je	prepare_vex
	cmp	[displacement_compression],1
	jne	prepare_vex
	cmp	edx,80h
	jb	prepare_vex
	cmp	edx,-80h
	jae	prepare_vex
	mov	al,bl
	or	al,bh
	shr	al,4
	cmp	al,2
	je	prepare_vex
	call	compress_displacement
	cmp	[displacement_compression],2
	ja	prepare_evex
	jb	prepare_vex
	dec	[displacement_compression]
	mov	edx,[uncompressed_displacement]
      prepare_vex:
	mov	ah,[extended_code]
	cmp	ah,38h
	je	store_vex_0f38_instruction_code
	cmp	ah,3Ah
	je	store_vex_0f3a_instruction_code
	test	[rex_prefix],1011b
	jnz	store_vex_0f_instruction_code
	mov	[edi+2],ah
	mov	byte [edi],0C5h
	mov	al,[vex_register]
	not	al
	shl	al,3
	mov	ah,[rex_prefix]
	shl	ah,5
	and	ah,80h
	xor	al,ah
	call	get_vex_lpp_bits
	mov	[edi+1],al
	call	check_vex
	add	edi,3
	ret
      get_vex_lpp_bits:
	cmp	[operand_size],32
	jne	get_vex_pp_bits
	or	al,100b
      get_vex_pp_bits:
	mov	ah,[opcode_prefix]
	cmp	ah,66h
	je	vex_66
	cmp	ah,0F3h
	je	vex_f3
	cmp	ah,0F2h
	je	vex_f2
	test	ah,ah
	jnz	disallowed_combination_of_registers
	ret
      vex_f2:
	or	al,11b
	ret
      vex_f3:
	or	al,10b
	ret
      vex_66:
	or	al,1
	ret
      store_vex_0f38_instruction_code:
	mov	al,11100010b
	mov	ah,[supplemental_code]
	jmp	make_c4_vex
      store_vex_0f3a_instruction_code:
	mov	al,11100011b
	mov	ah,[supplemental_code]
	jmp	make_c4_vex
      store_vex_0f_instruction_code:
	mov	al,11100001b
      make_c4_vex:
	mov	[edi+3],ah
	mov	byte [edi],0C4h
	mov	ah,[rex_prefix]
	shl	ah,5
	xor	al,ah
	mov	[edi+1],al
	call	check_vex
	mov	al,[vex_register]
	xor	al,1111b
	shl	al,3
	mov	ah,[rex_prefix]
	shl	ah,4
	and	ah,80h
	or	al,ah
	call	get_vex_lpp_bits
	mov	[edi+2],al
	add	edi,4
	ret
      check_vex:
	cmp	[code_type],64
	je	vex_ok
	not	al
	test	al,11000000b
	jnz	invalid_operand
	test	[rex_prefix],40h
	jnz	invalid_operand
      vex_ok:
	ret
store_xop_instruction_code:
	mov	[edi+3],al
	mov	byte [edi],8Fh
	mov	al,[xop_opcode_map]
	mov	ah,[rex_prefix]
	test	ah,40h
	jz	xop_ok
	cmp	[code_type],64
	jne	invalid_operand
      xop_ok:
	not	ah
	shl	ah,5
	xor	al,ah
	mov	[edi+1],al
	mov	al,[vex_register]
	xor	al,1111b
	shl	al,3
	mov	ah,[rex_prefix]
	shl	ah,4
	and	ah,80h
	or	al,ah
	call	get_vex_lpp_bits
	mov	[edi+2],al
	add	edi,4
	ret
store_evex_instruction_code:
	test	[vex_required],2
	jnz	invalid_operand
	cmp	[base_code],0Fh
	jne	invalid_operand
	cmp	[displacement_compression],1
	jne	prepare_evex
	call	compress_displacement
      prepare_evex:
	mov	ah,[extended_code]
	cmp	ah,38h
	je	store_evex_0f38_instruction_code
	cmp	ah,3Ah
	je	store_evex_0f3a_instruction_code
	mov	al,11110001b
      make_evex:
	mov	[edi+4],ah
	mov	byte [edi],62h
	mov	ah,[rex_prefix]
	shl	ah,5
	xor	al,ah
	mov	ah,[vex_required]
	and	ah,10h
	xor	al,ah
	mov	[edi+1],al
	call	check_vex
	mov	al,[vex_register]
	not	al
	and	al,1111b
	shl	al,3
	mov	ah,[rex_prefix]
	shl	ah,4
	or	ah,[rex_prefix]
	and	ah,80h
	or	al,ah
	or	al,100b
	call	get_vex_pp_bits
	mov	[edi+2],al
	mov	al,[vex_register]
	not	al
	shr	al,1
	and	al,1000b
	test	[vex_required],80h
	jne	evex_rounding
	mov	ah,[operand_size]
	cmp	ah,16
	jbe	evex_l_ok
	or	al,ah
	jmp	evex_l_ok
      evex_rounding:
	mov	ah,[rounding_mode]
	shl	ah,5
	or	al,ah
      evex_l_ok:
	test	[vex_required],20h
	jz	evex_zaaa_ok
	or	al,[mask_register]
      evex_zaaa_ok:
	test	[vex_required],40h
	jz	evex_b_ok
	or	al,10h
      evex_b_ok:
	mov	[edi+3],al
	add	edi,5
	ret
      store_evex_0f38_instruction_code:
	mov	al,11110010b
	mov	ah,[supplemental_code]
	jmp	make_evex
      store_evex_0f3a_instruction_code:
	mov	al,11110011b
	mov	ah,[supplemental_code]
	jmp	make_evex
compress_displacement:
	mov	ebp,ecx
	mov	[uncompressed_displacement],edx
	or	edx,edx
	jz	displacement_compressed
	xor	ecx,ecx
	mov	cl,[mmx_size]
	test	cl,cl
	jnz	calculate_displacement_scale
	mov	cl,[operand_size]
      calculate_displacement_scale:
	bsf	ecx,ecx
	jz	displacement_compression_ok
	xor	eax,eax
	shrd	eax,edx,cl
	jnz	displacement_not_compressed
	sar	edx,cl
	cmp	edx,80h
	jb	displacement_compressed
	cmp	edx,-80h
	jnb	displacement_compressed
	shl	edx,cl
      displacement_not_compressed:
	inc	[displacement_compression]
	jmp	displacement_compression_ok
      displacement_compressed:
	add	[displacement_compression],2
      displacement_compression_ok:
	mov	ecx,ebp
	ret



# ASM tables

comment_marker equ '#'

include_variable db 'INCLUDE',0

symbol_characters db 27
 db 9,0Ah,0Dh,1Ah,20h,'+-/*=<>()[]{}:,|&~!`#\'

preprocessor_directives:
 db 6,'define'
 dw define_symbolic_constant-directive_handler
 db 7,'include'
 dw include_file-directive_handler
 db 3,'irp'
 dw irp_directive-directive_handler
 db 4,'irps'
 dw irps_directive-directive_handler
 db 4,'irpv'
 dw irpv_directive-directive_handler
 db 4,'proc'
 dw define_macro-directive_handler
 db 5,'match'
 dw match_directive-directive_handler
 db 8,'postpone'
 dw postpone_directive-directive_handler
 db 5,'purge'
 dw purge_macro-directive_handler
 db 4,'rept'
 dw rept_directive-directive_handler
 db 7,'restore'
 dw restore_equ_constant-directive_handler
 db 7,'restruc'
 dw purge_struc-directive_handler
 db 5,'struc'
 dw define_struc-directive_handler
 db 0

macro_directives:
 db 6,'common'
 dw common_block-directive_handler
 db 7,'forward'
 dw forward_block-directive_handler
 db 5,'local'
 dw local_symbols-directive_handler
 db 7,'reverse'
 dw reverse_block-directive_handler
 db 0

operators:
 db 1,'+',80h
 db 1,'-',81h
 db 1,'*',90h
 db 1,'/',91h
 db 3,'and',0B0h
 db 3,'mod',0A0h
 db 2,'or',0B1h
 db 3,'shl',0C0h
 db 3,'shr',0C1h
 db 3,'xor',0B2h
 db 0

single_operand_operators:
 db 1,'+',82h
 db 1,'-',83h
 db 3,'bsf',0E0h
 db 3,'bsr',0E1h
 db 3,'not',0D0h
 db 3,'plt',0F1h
 db 3,'rva',0F0h
 db 0

directive_operators:
 db 5,'align',8Ch
 db 2,'as',86h
 db 2,'at',80h
 db 7,'defined',88h
 db 3,'dup',81h
 db 2,'eq',0F0h
 db 6,'eqtype',0F7h
 db 4,'from',82h
 db 2,'in',0F6h
 db 2,'on',84h
 db 3,'ptr',85h
 db 10,'relativeto',0F8h
 db 4,'used',89h
 db 0

address_sizes:
 db 4,'byte',1
 db 5,'dword',4
 db 5,'qword',8
 db 4,'word',2
 db 0

symbols:
 dw symbols_1-symbols,(symbols_2-symbols_1)/(1+2)
 dw symbols_2-symbols,(symbols_3-symbols_2)/(2+2)
 dw symbols_3-symbols,(symbols_4-symbols_3)/(3+2)
 dw symbols_4-symbols,(symbols_5-symbols_4)/(4+2)
 dw symbols_5-symbols,(symbols_6-symbols_5)/(5+2)
 dw symbols_6-symbols,(symbols_7-symbols_6)/(6+2)
 dw symbols_7-symbols,(symbols_8-symbols_7)/(7+2)
 dw symbols_8-symbols,(symbols_9-symbols_8)/(8+2)
 dw symbols_9-symbols,(symbols_10-symbols_9)/(9+2)
 dw symbols_10-symbols,(symbols_11-symbols_10)/(10+2)
 dw symbols_11-symbols,(symbols_end-symbols_11)/(11+2)

symbols_1:
 db 'z',1Fh,0
symbols_2:
 db 'ah',10h,04h
 db 'al',10h,10h
 db 'ax',10h,20h
 db 'bh',10h,07h
 db 'bl',10h,13h
 db 'bp',10h,25h
 db 'bx',10h,23h
 db 'ch',10h,05h
 db 'cl',10h,11h
 db 'cs',10h,32h
 db 'cx',10h,21h
 db 'dh',10h,06h
 db 'di',10h,27h
 db 'dl',10h,12h
 db 'ds',10h,34h
 db 'dx',10h,22h
 db 'es',10h,31h
 db 'fs',10h,35h
 db 'gs',10h,36h
 db 'k0',14h,50h
 db 'k1',14h,51h
 db 'k2',14h,52h
 db 'k3',14h,53h
 db 'k4',14h,54h
 db 'k5',14h,55h
 db 'k6',14h,56h
 db 'k7',14h,57h
 db 'ms',1Ch,41h
 db 'mz',18h,20h
 db 'nx',1Bh,83h
 db 'pe',18h,30h
 db 'r8',10h,88h
 db 'r9',10h,89h
 db 'rd',1Fh,21h
 db 'rn',1Fh,20h
 db 'ru',1Fh,22h
 db 'rz',1Fh,23h
 db 'si',10h,26h
 db 'sp',10h,24h
 db 'ss',10h,33h
 db 'st',10h,0A0h
symbols_3:
 db 'bpl',10h,15h
 db 'cr0',14h,00h
 db 'cr1',14h,01h
 db 'cr2',14h,02h
 db 'cr3',14h,03h
 db 'cr4',14h,04h
 db 'cr5',14h,05h
 db 'cr6',14h,06h
 db 'cr7',14h,07h
 db 'cr8',14h,08h
 db 'cr9',14h,09h
 db 'dil',10h,17h
 db 'dll',1Bh,80h
 db 'dr0',14h,10h
 db 'dr1',14h,11h
 db 'dr2',14h,12h
 db 'dr3',14h,13h
 db 'dr4',14h,14h
 db 'dr5',14h,15h
 db 'dr6',14h,16h
 db 'dr7',14h,17h
 db 'dr8',14h,18h
 db 'dr9',14h,19h
 db 'eax',10h,40h
 db 'ebp',10h,45h
 db 'ebx',10h,43h
 db 'ecx',10h,41h
 db 'edi',10h,47h
 db 'edx',10h,42h
 db 'efi',1Bh,10
 db 'eip',10h,94h
 db 'elf',18h,50h
 db 'esi',10h,46h
 db 'esp',10h,44h
 db 'far',12h,3
 db 'gui',1Bh,2
 db 'mm0',10h,0B0h
 db 'mm1',10h,0B1h
 db 'mm2',10h,0B2h
 db 'mm3',10h,0B3h
 db 'mm4',10h,0B4h
 db 'mm5',10h,0B5h
 db 'mm6',10h,0B6h
 db 'mm7',10h,0B7h
 db 'r10',10h,8Ah
 db 'r11',10h,8Bh
 db 'r12',10h,8Ch
 db 'r13',10h,8Dh
 db 'r14',10h,8Eh
 db 'r15',10h,8Fh
 db 'r8b',10h,18h
 db 'r8d',10h,48h
 db 'r8l',10h,18h
 db 'r8w',10h,28h
 db 'r9b',10h,19h
 db 'r9d',10h,49h
 db 'r9l',10h,19h
 db 'r9w',10h,29h
 db 'rax',10h,80h
 db 'rbp',10h,85h
 db 'rbx',10h,83h
 db 'rcx',10h,81h
 db 'rdi',10h,87h
 db 'rdx',10h,82h
 db 'rip',10h,98h
 db 'rsi',10h,86h
 db 'rsp',10h,84h
 db 'sae',1Fh,30h
 db 'sil',10h,16h
 db 'spl',10h,14h
 db 'st0',10h,0A0h
 db 'st1',10h,0A1h
 db 'st2',10h,0A2h
 db 'st3',10h,0A3h
 db 'st4',10h,0A4h
 db 'st5',10h,0A5h
 db 'st6',10h,0A6h
 db 'st7',10h,0A7h
 db 'tr0',14h,40h
 db 'tr1',14h,41h
 db 'tr2',14h,42h
 db 'tr3',14h,43h
 db 'tr4',14h,44h
 db 'tr5',14h,45h
 db 'tr6',14h,46h
 db 'tr7',14h,47h
 db 'wdm',1Bh,81h
symbols_4:
 db '1to2',1Fh,11h
 db '1to4',1Fh,12h
 db '1to8',1Fh,13h
 db 'bnd0',14h,60h
 db 'bnd1',14h,61h
 db 'bnd2',14h,62h
 db 'bnd3',14h,63h
 db 'byte',11h,1
 db 'code',19h,5
 db 'coff',18h,40h
 db 'cr10',14h,0Ah
 db 'cr11',14h,0Bh
 db 'cr12',14h,0Ch
 db 'cr13',14h,0Dh
 db 'cr14',14h,0Eh
 db 'cr15',14h,0Fh
 db 'data',19h,6
 db 'dr10',14h,1Ah
 db 'dr11',14h,1Bh
 db 'dr12',14h,1Ch
 db 'dr13',14h,1Dh
 db 'dr14',14h,1Eh
 db 'dr15',14h,1Fh
 db 'ms64',1Ch,49h
 db 'near',12h,2
 db 'note',1Eh,4
 db 'pe64',18h,3Ch
 db 'r10b',10h,1Ah
 db 'r10d',10h,4Ah
 db 'r10l',10h,1Ah
 db 'r10w',10h,2Ah
 db 'r11b',10h,1Bh
 db 'r11d',10h,4Bh
 db 'r11l',10h,1Bh
 db 'r11w',10h,2Bh
 db 'r12b',10h,1Ch
 db 'r12d',10h,4Ch
 db 'r12l',10h,1Ch
 db 'r12w',10h,2Ch
 db 'r13b',10h,1Dh
 db 'r13d',10h,4Dh
 db 'r13l',10h,1Dh
 db 'r13w',10h,2Dh
 db 'r14b',10h,1Eh
 db 'r14d',10h,4Eh
 db 'r14l',10h,1Eh
 db 'r14w',10h,2Eh
 db 'r15b',10h,1Fh
 db 'r15d',10h,4Fh
 db 'r15l',10h,1Fh
 db 'r15w',10h,2Fh
 db 'word',11h,2
 db 'xmm0',10h,0C0h
 db 'xmm1',10h,0C1h
 db 'xmm2',10h,0C2h
 db 'xmm3',10h,0C3h
 db 'xmm4',10h,0C4h
 db 'xmm5',10h,0C5h
 db 'xmm6',10h,0C6h
 db 'xmm7',10h,0C7h
 db 'xmm8',10h,0C8h
 db 'xmm9',10h,0C9h
 db 'ymm0',10h,0E0h
 db 'ymm1',10h,0E1h
 db 'ymm2',10h,0E2h
 db 'ymm3',10h,0E3h
 db 'ymm4',10h,0E4h
 db 'ymm5',10h,0E5h
 db 'ymm6',10h,0E6h
 db 'ymm7',10h,0E7h
 db 'ymm8',10h,0E8h
 db 'ymm9',10h,0E9h
 db 'zmm0',10h,60h
 db 'zmm1',10h,61h
 db 'zmm2',10h,62h
 db 'zmm3',10h,63h
 db 'zmm4',10h,64h
 db 'zmm5',10h,65h
 db 'zmm6',10h,66h
 db 'zmm7',10h,67h
 db 'zmm8',10h,68h
 db 'zmm9',10h,69h
symbols_5:
 db '1to16',1Fh,14h
 db 'dword',11h,4
 db 'elf64',18h,58h
 db 'fword',11h,6
 db 'large',1Bh,82h
 db 'pword',11h,6
 db 'qword',11h,8
 db 'short',12h,1
 db 'tbyte',11h,0Ah
 db 'tword',11h,0Ah
 db 'use16',13h,16
 db 'use32',13h,32
 db 'use64',13h,64
 db 'xmm10',10h,0CAh
 db 'xmm11',10h,0CBh
 db 'xmm12',10h,0CCh
 db 'xmm13',10h,0CDh
 db 'xmm14',10h,0CEh
 db 'xmm15',10h,0CFh
 db 'xmm16',10h,0D0h
 db 'xmm17',10h,0D1h
 db 'xmm18',10h,0D2h
 db 'xmm19',10h,0D3h
 db 'xmm20',10h,0D4h
 db 'xmm21',10h,0D5h
 db 'xmm22',10h,0D6h
 db 'xmm23',10h,0D7h
 db 'xmm24',10h,0D8h
 db 'xmm25',10h,0D9h
 db 'xmm26',10h,0DAh
 db 'xmm27',10h,0DBh
 db 'xmm28',10h,0DCh
 db 'xmm29',10h,0DDh
 db 'xmm30',10h,0DEh
 db 'xmm31',10h,0DFh
 db 'xword',11h,16
 db 'ymm10',10h,0EAh
 db 'ymm11',10h,0EBh
 db 'ymm12',10h,0ECh
 db 'ymm13',10h,0EDh
 db 'ymm14',10h,0EEh
 db 'ymm15',10h,0EFh
 db 'ymm16',10h,0F0h
 db 'ymm17',10h,0F1h
 db 'ymm18',10h,0F2h
 db 'ymm19',10h,0F3h
 db 'ymm20',10h,0F4h
 db 'ymm21',10h,0F5h
 db 'ymm22',10h,0F6h
 db 'ymm23',10h,0F7h
 db 'ymm24',10h,0F8h
 db 'ymm25',10h,0F9h
 db 'ymm26',10h,0FAh
 db 'ymm27',10h,0FBh
 db 'ymm28',10h,0FCh
 db 'ymm29',10h,0FDh
 db 'ymm30',10h,0FEh
 db 'ymm31',10h,0FFh
 db 'yword',11h,32
 db 'zmm10',10h,6Ah
 db 'zmm11',10h,6Bh
 db 'zmm12',10h,6Ch
 db 'zmm13',10h,6Dh
 db 'zmm14',10h,6Eh
 db 'zmm15',10h,6Fh
 db 'zmm16',10h,70h
 db 'zmm17',10h,71h
 db 'zmm18',10h,72h
 db 'zmm19',10h,73h
 db 'zmm20',10h,74h
 db 'zmm21',10h,75h
 db 'zmm22',10h,76h
 db 'zmm23',10h,77h
 db 'zmm24',10h,78h
 db 'zmm25',10h,79h
 db 'zmm26',10h,7Ah
 db 'zmm27',10h,7Bh
 db 'zmm28',10h,7Ch
 db 'zmm29',10h,7Dh
 db 'zmm30',10h,7Eh
 db 'zmm31',10h,7Fh
 db 'zword',11h,64
symbols_6:
 db 'binary',18h,10h
 db 'dqword',11h,16
 db 'export',1Ah,0
 db 'fixups',1Ah,5
 db 'import',1Ah,1
 db 'native',1Bh,1
 db 'qqword',11h,32
 db 'static',1Dh,1
symbols_7:
 db 'console',1Bh,3
 db 'dqqword',11h,64
 db 'dynamic',1Eh,2
 db 'efiboot',1Bh,11
symbols_8:
 db 'linkinfo',19h,9
 db 'readable',19h,30
 db 'resource',1Ah,2
 db 'writable',19h,31
symbols_9:
 db 'shareable',19h,28
 db 'writeable',19h,31
symbols_10:
 db 'efiruntime',1Bh,12
 db 'executable',19h,29
 db 'linkremove',19h,11
symbols_11:
 db 'discardable',19h,25
 db 'interpreter',1Eh,3
 db 'notpageable',19h,27
symbols_end:

instructions:
 dw instructions_2-instructions,(instructions_3-instructions_2)/(2+3)
 dw instructions_3-instructions,(instructions_4-instructions_3)/(3+3)
 dw instructions_4-instructions,(instructions_5-instructions_4)/(4+3)
 dw instructions_5-instructions,(instructions_6-instructions_5)/(5+3)
 dw instructions_6-instructions,(instructions_7-instructions_6)/(6+3)
 dw instructions_7-instructions,(instructions_8-instructions_7)/(7+3)
 dw instructions_8-instructions,(instructions_9-instructions_8)/(8+3)
 dw instructions_9-instructions,(instructions_10-instructions_9)/(9+3)
 dw instructions_10-instructions,(instructions_11-instructions_10)/(10+3)
 dw instructions_11-instructions,(instructions_12-instructions_11)/(11+3)
 dw instructions_12-instructions,(instructions_13-instructions_12)/(12+3)
 dw instructions_13-instructions,(instructions_14-instructions_13)/(13+3)
 dw instructions_14-instructions,(instructions_15-instructions_14)/(14+3)
 dw instructions_15-instructions,(instructions_16-instructions_15)/(15+3)
 dw instructions_16-instructions,(instructions_end-instructions_16)/(16+3)

instructions_2:
 db 'bt',4
 dw bt_instruction-instruction_handler
 db 'if',0
 dw if_directive-instruction_handler
 db 'in',0
 dw in_instruction-instruction_handler
 db 'ja',77h
 dw conditional_jump-instruction_handler
 db 'jb',72h
 dw conditional_jump-instruction_handler
 db 'jc',72h
 dw conditional_jump-instruction_handler
 db 'je',74h
 dw conditional_jump-instruction_handler
 db 'jg',7Fh
 dw conditional_jump-instruction_handler
 db 'jl',7Ch
 dw conditional_jump-instruction_handler
 db 'jo',70h
 dw conditional_jump-instruction_handler
 db 'jp',7Ah
 dw conditional_jump-instruction_handler
 db 'js',78h
 dw conditional_jump-instruction_handler
 db 'jz',74h
 dw conditional_jump-instruction_handler
 db 'or',08h
 dw basic_instruction-instruction_handler
instructions_3:
 db 'aaa',37h
 dw simple_instruction_except64-instruction_handler
 db 'aad',0D5h
 dw aa_instruction-instruction_handler
 db 'aam',0D4h
 dw aa_instruction-instruction_handler
 db 'aas',3Fh
 dw simple_instruction_except64-instruction_handler
 db 'adc',10h
 dw basic_instruction-instruction_handler
 db 'add',00h
 dw basic_instruction-instruction_handler
 db 'and',20h
 dw basic_instruction-instruction_handler
 db 'bnd',0F2h
 dw bnd_prefix_instruction-instruction_handler
 db 'bsf',0BCh
 dw bs_instruction-instruction_handler
 db 'bsr',0BDh
 dw bs_instruction-instruction_handler
 db 'btc',7
 dw bt_instruction-instruction_handler
 db 'btr',6
 dw bt_instruction-instruction_handler
 db 'bts',5
 dw bt_instruction-instruction_handler
 db 'cbw',98h
 dw simple_instruction_16bit-instruction_handler
 db 'cdq',99h
 dw simple_instruction_32bit-instruction_handler
 db 'clc',0F8h
 dw simple_instruction-instruction_handler
 db 'cld',0FCh
 dw simple_instruction-instruction_handler
 db 'cli',0FAh
 dw simple_instruction-instruction_handler
 db 'cmc',0F5h
 dw simple_instruction-instruction_handler
 db 'cmp',38h
 dw basic_instruction-instruction_handler
 db 'cqo',99h
 dw simple_instruction_64bit-instruction_handler
 db 'cwd',99h
 dw simple_instruction_16bit-instruction_handler
 db 'daa',27h
 dw simple_instruction_except64-instruction_handler
 db 'das',2Fh
 dw simple_instruction_except64-instruction_handler
 db 'dec',1
 dw inc_instruction-instruction_handler
 db 'div',6
 dw single_operand_instruction-instruction_handler
 db 'end',0
 dw end_directive-instruction_handler
 db 'err',0
 dw err_directive-instruction_handler
 db 'fld',0
 dw fld_instruction-instruction_handler
 db 'fst',2
 dw fld_instruction-instruction_handler
 db 'hlt',0F4h
 dw simple_instruction-instruction_handler
 db 'inc',0
 dw inc_instruction-instruction_handler
 db 'ins',6Ch
 dw ins_instruction-instruction_handler
 db 'int',0CDh
 dw int_instruction-instruction_handler
 db 'jae',73h
 dw conditional_jump-instruction_handler
 db 'jbe',76h
 dw conditional_jump-instruction_handler
 db 'jge',7Dh
 dw conditional_jump-instruction_handler
 db 'jle',7Eh
 dw conditional_jump-instruction_handler
 db 'jmp',0
 dw jmp_instruction-instruction_handler
 db 'jna',76h
 dw conditional_jump-instruction_handler
 db 'jnb',73h
 dw conditional_jump-instruction_handler
 db 'jnc',73h
 dw conditional_jump-instruction_handler
 db 'jne',75h
 dw conditional_jump-instruction_handler
 db 'jng',7Eh
 dw conditional_jump-instruction_handler
 db 'jnl',7Dh
 dw conditional_jump-instruction_handler
 db 'jno',71h
 dw conditional_jump-instruction_handler
 db 'jnp',7Bh
 dw conditional_jump-instruction_handler
 db 'jns',79h
 dw conditional_jump-instruction_handler
 db 'jnz',75h
 dw conditional_jump-instruction_handler
 db 'jpe',7Ah
 dw conditional_jump-instruction_handler
 db 'jpo',7Bh
 dw conditional_jump-instruction_handler
 db 'lar',2
 dw lar_instruction-instruction_handler
 db 'lds',3
 dw ls_instruction-instruction_handler
 db 'lea',0
 dw lea_instruction-instruction_handler
 db 'les',0
 dw ls_instruction-instruction_handler
 db 'lfs',4
 dw ls_instruction-instruction_handler
 db 'lgs',5
 dw ls_instruction-instruction_handler
 db 'lsl',3
 dw lar_instruction-instruction_handler
 db 'lss',2
 dw ls_instruction-instruction_handler
 db 'ltr',3
 dw pm_word_instruction-instruction_handler
 db 'mov',0
 dw mov_instruction-instruction_handler
 db 'mul',4
 dw single_operand_instruction-instruction_handler
 db 'neg',3
 dw single_operand_instruction-instruction_handler
 db 'nop',90h
 dw nop_instruction-instruction_handler
 db 'not',2
 dw single_operand_instruction-instruction_handler
 db 'org',0
 dw org_directive-instruction_handler
 db 'out',0
 dw out_instruction-instruction_handler
 db 'pop',0
 dw pop_instruction-instruction_handler
 db 'por',0EBh
 dw basic_mmx_instruction-instruction_handler
 db 'rcl',2
 dw sh_instruction-instruction_handler
 db 'rcr',3
 dw sh_instruction-instruction_handler
 db 'rep',0F3h
 dw prefix_instruction-instruction_handler
 db 'ret',0C2h
 dw ret_instruction-instruction_handler
 db 'rol',0
 dw sh_instruction-instruction_handler
 db 'ror',1
 dw sh_instruction-instruction_handler
 db 'rsm',0AAh
 dw simple_extended_instruction-instruction_handler
 db 'sal',4
 dw sh_instruction-instruction_handler
 db 'sar',7
 dw sh_instruction-instruction_handler
 db 'sbb',18h
 dw basic_instruction-instruction_handler
 db 'shl',4
 dw sh_instruction-instruction_handler
 db 'shr',5
 dw sh_instruction-instruction_handler
 db 'stc',0F9h
 dw simple_instruction-instruction_handler
 db 'std',0FDh
 dw simple_instruction-instruction_handler
 db 'sti',0FBh
 dw simple_instruction-instruction_handler
 db 'str',1
 dw pm_store_word_instruction-instruction_handler
 db 'sub',28h
 dw basic_instruction-instruction_handler
 db 'ud2',0Bh
 dw simple_extended_instruction-instruction_handler
 db 'xor',30h
 dw basic_instruction-instruction_handler
instructions_4:
 db 'adcx',66h
 dw adx_instruction-instruction_handler
 db 'adox',0F3h
 dw adx_instruction-instruction_handler
 db 'andn',0F2h
 dw andn_instruction-instruction_handler
 db 'arpl',0
 dw arpl_instruction-instruction_handler
 db 'blci',26h
 dw tbm_instruction-instruction_handler
 db 'blcs',13h
 dw tbm_instruction-instruction_handler
 db 'blsi',3
 dw bmi_instruction-instruction_handler
 db 'blsr',1
 dw bmi_instruction-instruction_handler
 db 'bzhi',0F5h
 dw bzhi_instruction-instruction_handler
 db 'call',0
 dw call_instruction-instruction_handler
 db 'cdqe',98h
 dw simple_instruction_64bit-instruction_handler
 db 'clac',0CAh
 dw simple_vmx_instruction-instruction_handler
 db 'clgi',0DDh
 dw simple_vmx_instruction-instruction_handler
 db 'clts',6
 dw simple_extended_instruction-instruction_handler
 db 'clwb',6
 dw clflushopt_instruction-instruction_handler
 db 'cmps',0A6h
 dw cmps_instruction-instruction_handler
 db 'cwde',98h
 dw simple_instruction_32bit-instruction_handler
 db 'data',0
 dw data_directive-instruction_handler
 db 'dppd',41h
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'dpps',40h
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'else',0
 dw else_directive-instruction_handler
 db 'emms',77h
 dw simple_extended_instruction-instruction_handler
 db 'fabs',100001b
 dw simple_fpu_instruction-instruction_handler
 db 'fadd',0
 dw basic_fpu_instruction-instruction_handler
 db 'fbld',4
 dw fbld_instruction-instruction_handler
 db 'fchs',100000b
 dw simple_fpu_instruction-instruction_handler
 db 'fcom',2
 dw basic_fpu_instruction-instruction_handler
 db 'fcos',111111b
 dw simple_fpu_instruction-instruction_handler
 db 'fdiv',6
 dw basic_fpu_instruction-instruction_handler
 db 'feni',0E0h
 dw finit_instruction-instruction_handler
 db 'fild',0
 dw fild_instruction-instruction_handler
 db 'fist',2
 dw fild_instruction-instruction_handler
 db 'fld1',101000b
 dw simple_fpu_instruction-instruction_handler
 db 'fldz',101110b
 dw simple_fpu_instruction-instruction_handler
 db 'fmul',1
 dw basic_fpu_instruction-instruction_handler
 db 'fnop',010000b
 dw simple_fpu_instruction-instruction_handler
 db 'fsin',111110b
 dw simple_fpu_instruction-instruction_handler
 db 'fstp',3
 dw fld_instruction-instruction_handler
 db 'fsub',4
 dw basic_fpu_instruction-instruction_handler
 db 'ftst',100100b
 dw simple_fpu_instruction-instruction_handler
 db 'fxam',100101b
 dw simple_fpu_instruction-instruction_handler
 db 'fxch',0
 dw fxch_instruction-instruction_handler
 db 'heap',0
 dw heap_directive-instruction_handler
 db 'idiv',7
 dw single_operand_instruction-instruction_handler
 db 'imul',0
 dw imul_instruction-instruction_handler
 db 'insb',6Ch
 dw simple_instruction-instruction_handler
 db 'insd',6Dh
 dw simple_instruction_32bit-instruction_handler
 db 'insw',6Dh
 dw simple_instruction_16bit-instruction_handler
 db 'int1',0F1h
 dw simple_instruction-instruction_handler
 db 'int3',0CCh
 dw simple_instruction-instruction_handler
 db 'into',0CEh
 dw simple_instruction_except64-instruction_handler
 db 'invd',8
 dw simple_extended_instruction-instruction_handler
 db 'iret',0CFh
 dw iret_instruction-instruction_handler
 db 'jcxz',0E3h
 dw loop_instruction_16bit-instruction_handler
 db 'jnae',72h
 dw conditional_jump-instruction_handler
 db 'jnbe',77h
 dw conditional_jump-instruction_handler
 db 'jnge',7Ch
 dw conditional_jump-instruction_handler
 db 'jnle',7Fh
 dw conditional_jump-instruction_handler
 db 'korb',45h
 dw mask_instruction_b-instruction_handler
 db 'kord',45h
 dw mask_instruction_d-instruction_handler
 db 'korq',45h
 dw mask_instruction_q-instruction_handler
 db 'korw',45h
 dw mask_instruction_w-instruction_handler
 db 'lahf',9Fh
 dw simple_instruction-instruction_handler
 db 'lgdt',2
 dw lgdt_instruction-instruction_handler
 db 'lidt',3
 dw lgdt_instruction-instruction_handler
 db 'lldt',2
 dw pm_word_instruction-instruction_handler
 db 'lmsw',16h
 dw pm_word_instruction-instruction_handler
 db 'load',0
 dw load_directive-instruction_handler
 db 'lock',0F0h
 dw prefix_instruction-instruction_handler
 db 'lods',0ACh
 dw lods_instruction-instruction_handler
 db 'loop',0E2h
 dw loop_instruction-instruction_handler
 db 'movd',0
 dw movd_instruction-instruction_handler
 db 'movq',0
 dw movq_instruction-instruction_handler
 db 'movs',0A4h
 dw movs_instruction-instruction_handler
 db 'mulx',0F6h
 dw pdep_instruction-instruction_handler
 db 'orpd',56h
 dw sse_pd_instruction-instruction_handler
 db 'orps',56h
 dw sse_ps_instruction-instruction_handler
 db 'outs',6Eh
 dw outs_instruction-instruction_handler
 db 'pand',0DBh
 dw basic_mmx_instruction-instruction_handler
 db 'pdep',0F5h
 dw pdep_instruction-instruction_handler
 db 'pext',0F5h
 dw pext_instruction-instruction_handler
 db 'popa',61h
 dw simple_instruction_except64-instruction_handler
 db 'popd',4
 dw pop_instruction-instruction_handler
 db 'popf',9Dh
 dw simple_instruction-instruction_handler
 db 'popq',8
 dw pop_instruction-instruction_handler
 db 'popw',2
 dw pop_instruction-instruction_handler
 db 'push',0
 dw push_instruction-instruction_handler
 db 'pxor',0EFh
 dw basic_mmx_instruction-instruction_handler
 db 'repe',0F3h
 dw prefix_instruction-instruction_handler
 db 'repz',0F3h
 dw prefix_instruction-instruction_handler
 db 'retd',0C2h
 dw ret_instruction_32bit_except64-instruction_handler
 db 'retf',0CAh
 dw retf_instruction-instruction_handler
 db 'retn',0C2h
 dw ret_instruction-instruction_handler
 db 'retq',0C2h
 dw ret_instruction_only64-instruction_handler
 db 'retw',0C2h
 dw ret_instruction_16bit-instruction_handler
 db 'rorx',0F0h
 dw rorx_instruction-instruction_handler
 db 'sahf',9Eh
 dw simple_instruction-instruction_handler
 db 'salc',0D6h
 dw simple_instruction_except64-instruction_handler
 db 'sarx',0F7h
 dw sarx_instruction-instruction_handler
 db 'scas',0AEh
 dw stos_instruction-instruction_handler
 db 'seta',97h
 dw set_instruction-instruction_handler
 db 'setb',92h
 dw set_instruction-instruction_handler
 db 'setc',92h
 dw set_instruction-instruction_handler
 db 'sete',94h
 dw set_instruction-instruction_handler
 db 'setg',9Fh
 dw set_instruction-instruction_handler
 db 'setl',9Ch
 dw set_instruction-instruction_handler
 db 'seto',90h
 dw set_instruction-instruction_handler
 db 'setp',9Ah
 dw set_instruction-instruction_handler
 db 'sets',98h
 dw set_instruction-instruction_handler
 db 'setz',94h
 dw set_instruction-instruction_handler
 db 'sgdt',0
 dw lgdt_instruction-instruction_handler
 db 'shld',0A4h
 dw shd_instruction-instruction_handler
 db 'shlx',0F7h
 dw shlx_instruction-instruction_handler
 db 'shrd',0ACh
 dw shd_instruction-instruction_handler
 db 'shrx',0F7h
 dw shrx_instruction-instruction_handler
 db 'sidt',1
 dw lgdt_instruction-instruction_handler
 db 'sldt',0
 dw pm_store_word_instruction-instruction_handler
 db 'smsw',14h
 dw pm_store_word_instruction-instruction_handler
 db 'stac',0CBh
 dw simple_vmx_instruction-instruction_handler
 db 'stgi',0DCh
 dw simple_vmx_instruction-instruction_handler
 db 'stos',0AAh
 dw stos_instruction-instruction_handler
 db 'test',0
 dw test_instruction-instruction_handler
 db 'verr',4
 dw pm_word_instruction-instruction_handler
 db 'verw',5
 dw pm_word_instruction-instruction_handler
 db 'vpor',0EBh
 dw avx_pd_instruction_noevex-instruction_handler
 db 'wait',9Bh
 dw simple_instruction-instruction_handler
 db 'xadd',0C0h
 dw basic_486_instruction-instruction_handler
 db 'xchg',0
 dw xchg_instruction-instruction_handler
 db 'xend',0D5h
 dw simple_vmx_instruction-instruction_handler
 db 'xlat',0D7h
 dw xlat_instruction-instruction_handler
instructions_5:
 db 'addpd',58h
 dw sse_pd_instruction-instruction_handler
 db 'addps',58h
 dw sse_ps_instruction-instruction_handler
 db 'addsd',58h
 dw sse_sd_instruction-instruction_handler
 db 'addss',58h
 dw sse_ss_instruction-instruction_handler
 db 'align',0
 dw align_directive-instruction_handler
 db 'andpd',54h
 dw sse_pd_instruction-instruction_handler
 db 'andps',54h
 dw sse_ps_instruction-instruction_handler
 db 'bextr',0F7h
 dw bextr_instruction-instruction_handler
 db 'blcic',15h
 dw tbm_instruction-instruction_handler
 db 'blsic',16h
 dw tbm_instruction-instruction_handler
 db 'bndcl',1Ah
 dw bndcl_instruction-instruction_handler
 db 'bndcn',1Bh
 dw bndcu_instruction-instruction_handler
 db 'bndcu',1Ah
 dw bndcu_instruction-instruction_handler
 db 'bndmk',1Bh
 dw bndmk_instruction-instruction_handler
 db 'bound',0
 dw bound_instruction-instruction_handler
 db 'break',0
 dw break_directive-instruction_handler
 db 'bswap',0
 dw bswap_instruction-instruction_handler
 db 'cmova',47h
 dw bs_instruction-instruction_handler
 db 'cmovb',42h
 dw bs_instruction-instruction_handler
 db 'cmovc',42h
 dw bs_instruction-instruction_handler
 db 'cmove',44h
 dw bs_instruction-instruction_handler
 db 'cmovg',4Fh
 dw bs_instruction-instruction_handler
 db 'cmovl',4Ch
 dw bs_instruction-instruction_handler
 db 'cmovo',40h
 dw bs_instruction-instruction_handler
 db 'cmovp',4Ah
 dw bs_instruction-instruction_handler
 db 'cmovs',48h
 dw bs_instruction-instruction_handler
 db 'cmovz',44h
 dw bs_instruction-instruction_handler
 db 'cmppd',-1
 dw cmp_pd_instruction-instruction_handler
 db 'cmpps',-1
 dw cmp_ps_instruction-instruction_handler
 db 'cmpsb',0A6h
 dw simple_instruction-instruction_handler
 db 'cmpsd',-1
 dw cmpsd_instruction-instruction_handler
 db 'cmpsq',0A7h
 dw simple_instruction_64bit-instruction_handler
 db 'cmpss',-1
 dw cmp_ss_instruction-instruction_handler
 db 'cmpsw',0A7h
 dw simple_instruction_16bit-instruction_handler
 db 'cpuid',0A2h
 dw simple_extended_instruction-instruction_handler
 db 'crc32',0
 dw crc32_instruction-instruction_handler
 db 'divpd',5Eh
 dw sse_pd_instruction-instruction_handler
 db 'divps',5Eh
 dw sse_ps_instruction-instruction_handler
 db 'divsd',5Eh
 dw sse_sd_instruction-instruction_handler
 db 'divss',5Eh
 dw sse_ss_instruction-instruction_handler
 db 'enter',0
 dw enter_instruction-instruction_handler
 db 'entry',0
 dw entry_directive-instruction_handler
 db 'extrn',0
 dw extrn_directive-instruction_handler
 db 'extrq',0
 dw extrq_instruction-instruction_handler
 db 'f2xm1',110000b
 dw simple_fpu_instruction-instruction_handler
 db 'faddp',0
 dw faddp_instruction-instruction_handler
 db 'fbstp',6
 dw fbld_instruction-instruction_handler
 db 'fclex',0E2h
 dw finit_instruction-instruction_handler
 db 'fcomi',0F0h
 dw fcomi_instruction-instruction_handler
 db 'fcomp',3
 dw basic_fpu_instruction-instruction_handler
 db 'fdisi',0E1h
 dw finit_instruction-instruction_handler
 db 'fdivp',7
 dw faddp_instruction-instruction_handler
 db 'fdivr',7
 dw basic_fpu_instruction-instruction_handler
 db 'femms',0Eh
 dw simple_extended_instruction-instruction_handler
 db 'ffree',0
 dw ffree_instruction-instruction_handler
 db 'fiadd',0
 dw fi_instruction-instruction_handler
 db 'ficom',2
 dw fi_instruction-instruction_handler
 db 'fidiv',6
 dw fi_instruction-instruction_handler
 db 'fimul',1
 dw fi_instruction-instruction_handler
 db 'finit',0E3h
 dw finit_instruction-instruction_handler
 db 'fistp',3
 dw fild_instruction-instruction_handler
 db 'fisub',4
 dw fi_instruction-instruction_handler
 db 'fldcw',5
 dw fldcw_instruction-instruction_handler
 db 'fldpi',101011b
 dw simple_fpu_instruction-instruction_handler
 db 'fmulp',1
 dw faddp_instruction-instruction_handler
 db 'fneni',0E0h
 dw fninit_instruction-instruction_handler
 db 'fprem',111000b
 dw simple_fpu_instruction-instruction_handler
 db 'fptan',110010b
 dw simple_fpu_instruction-instruction_handler
 db 'fsave',6
 dw fsave_instruction-instruction_handler
 db 'fsqrt',111010b
 dw simple_fpu_instruction-instruction_handler
 db 'fstcw',7
 dw fstcw_instruction-instruction_handler
 db 'fstsw',0
 dw fstsw_instruction-instruction_handler
 db 'fsubp',5
 dw faddp_instruction-instruction_handler
 db 'fsubr',5
 dw basic_fpu_instruction-instruction_handler
 db 'fucom',4
 dw ffree_instruction-instruction_handler
 db 'fwait',9Bh
 dw simple_instruction-instruction_handler
 db 'fyl2x',110001b
 dw simple_fpu_instruction-instruction_handler
 db 'icebp',0F1h
 dw simple_instruction-instruction_handler
 db 'iretd',0CFh
 dw simple_instruction_32bit-instruction_handler
 db 'iretq',0CFh
 dw simple_instruction_64bit-instruction_handler
 db 'iretw',0CFh
 dw simple_instruction_16bit-instruction_handler
 db 'jecxz',0E3h
 dw loop_instruction_32bit-instruction_handler
 db 'jrcxz',0E3h
 dw loop_instruction_64bit-instruction_handler
 db 'kaddb',4Ah
 dw mask_instruction_b-instruction_handler
 db 'kaddd',4Ah
 dw mask_instruction_d-instruction_handler
 db 'kaddq',4Ah
 dw mask_instruction_q-instruction_handler
 db 'kaddw',4Ah
 dw mask_instruction_w-instruction_handler
 db 'kandb',41h
 dw mask_instruction_b-instruction_handler
 db 'kandd',41h
 dw mask_instruction_d-instruction_handler
 db 'kandq',41h
 dw mask_instruction_q-instruction_handler
 db 'kandw',41h
 dw mask_instruction_w-instruction_handler
 db 'kmovb',1
 dw kmov_instruction-instruction_handler
 db 'kmovd',4
 dw kmov_instruction-instruction_handler
 db 'kmovq',8
 dw kmov_instruction-instruction_handler
 db 'kmovw',2
 dw kmov_instruction-instruction_handler
 db 'knotb',44h
 dw mask_instruction_single_source_b-instruction_handler
 db 'knotd',44h
 dw mask_instruction_single_source_d-instruction_handler
 db 'knotq',44h
 dw mask_instruction_single_source_q-instruction_handler
 db 'knotw',44h
 dw mask_instruction_single_source_w-instruction_handler
 db 'kxorb',47h
 dw mask_instruction_b-instruction_handler
 db 'kxord',47h
 dw mask_instruction_d-instruction_handler
 db 'kxorq',47h
 dw mask_instruction_q-instruction_handler
 db 'kxorw',47h
 dw mask_instruction_w-instruction_handler
 db 'label',0
 dw label_directive-instruction_handler
 db 'lddqu',0
 dw lddqu_instruction-instruction_handler
 db 'leave',0C9h
 dw simple_instruction-instruction_handler
 db 'lodsb',0ACh
 dw simple_instruction-instruction_handler
 db 'lodsd',0ADh
 dw simple_instruction_32bit-instruction_handler
 db 'lodsq',0ADh
 dw simple_instruction_64bit-instruction_handler
 db 'lodsw',0ADh
 dw simple_instruction_16bit-instruction_handler
 db 'loopd',0E2h
 dw loop_instruction_32bit-instruction_handler
 db 'loope',0E1h
 dw loop_instruction-instruction_handler
 db 'loopq',0E2h
 dw loop_instruction_64bit-instruction_handler
 db 'loopw',0E2h
 dw loop_instruction_16bit-instruction_handler
 db 'loopz',0E1h
 dw loop_instruction-instruction_handler
 db 'lzcnt',0BDh
 dw popcnt_instruction-instruction_handler
 db 'maxpd',5Fh
 dw sse_pd_instruction-instruction_handler
 db 'maxps',5Fh
 dw sse_ps_instruction-instruction_handler
 db 'maxsd',5Fh
 dw sse_sd_instruction-instruction_handler
 db 'maxss',5Fh
 dw sse_ss_instruction-instruction_handler
 db 'minpd',5Dh
 dw sse_pd_instruction-instruction_handler
 db 'minps',5Dh
 dw sse_ps_instruction-instruction_handler
 db 'minsd',5Dh
 dw sse_sd_instruction-instruction_handler
 db 'minss',5Dh
 dw sse_ss_instruction-instruction_handler
 db 'movbe',0F0h
 dw movbe_instruction-instruction_handler
 db 'movsb',0A4h
 dw simple_instruction-instruction_handler
 db 'movsd',0
 dw movsd_instruction-instruction_handler
 db 'movsq',0A5h
 dw simple_instruction_64bit-instruction_handler
 db 'movss',0
 dw movss_instruction-instruction_handler
 db 'movsw',0A5h
 dw simple_instruction_16bit-instruction_handler
 db 'movsx',0BEh
 dw movx_instruction-instruction_handler
 db 'movzx',0B6h
 dw movx_instruction-instruction_handler
 db 'mulpd',59h
 dw sse_pd_instruction-instruction_handler
 db 'mulps',59h
 dw sse_ps_instruction-instruction_handler
 db 'mulsd',59h
 dw sse_sd_instruction-instruction_handler
 db 'mulss',59h
 dw sse_ss_instruction-instruction_handler
 db 'mwait',0C9h
 dw monitor_instruction-instruction_handler
 db 'outsb',6Eh
 dw simple_instruction-instruction_handler
 db 'outsd',6Fh
 dw simple_instruction_32bit-instruction_handler
 db 'outsw',6Fh
 dw simple_instruction_16bit-instruction_handler
 db 'pabsb',1Ch
 dw ssse3_instruction-instruction_handler
 db 'pabsd',1Eh
 dw ssse3_instruction-instruction_handler
 db 'pabsw',1Dh
 dw ssse3_instruction-instruction_handler
 db 'paddb',0FCh
 dw basic_mmx_instruction-instruction_handler
 db 'paddd',0FEh
 dw basic_mmx_instruction-instruction_handler
 db 'paddq',0D4h
 dw basic_mmx_instruction-instruction_handler
 db 'paddw',0FDh
 dw basic_mmx_instruction-instruction_handler
 db 'pandn',0DFh
 dw basic_mmx_instruction-instruction_handler
 db 'pause',0
 dw pause_instruction-instruction_handler
 db 'pavgb',0E0h
 dw basic_mmx_instruction-instruction_handler
 db 'pavgw',0E3h
 dw basic_mmx_instruction-instruction_handler
 db 'pf2id',1Dh
 dw amd3dnow_instruction-instruction_handler
 db 'pf2iw',1Ch
 dw amd3dnow_instruction-instruction_handler
 db 'pfacc',0AEh
 dw amd3dnow_instruction-instruction_handler
 db 'pfadd',9Eh
 dw amd3dnow_instruction-instruction_handler
 db 'pfmax',0A4h
 dw amd3dnow_instruction-instruction_handler
 db 'pfmin',94h
 dw amd3dnow_instruction-instruction_handler
 db 'pfmul',0B4h
 dw amd3dnow_instruction-instruction_handler
 db 'pfrcp',96h
 dw amd3dnow_instruction-instruction_handler
 db 'pfsub',9Ah
 dw amd3dnow_instruction-instruction_handler
 db 'pi2fd',0Dh
 dw amd3dnow_instruction-instruction_handler
 db 'pi2fw',0Ch
 dw amd3dnow_instruction-instruction_handler
 db 'popad',61h
 dw simple_instruction_32bit_except64-instruction_handler
 db 'popaw',61h
 dw simple_instruction_16bit_except64-instruction_handler
 db 'popfd',9Dh
 dw simple_instruction_32bit_except64-instruction_handler
 db 'popfq',9Dh
 dw simple_instruction_only64-instruction_handler
 db 'popfw',9Dh
 dw simple_instruction_16bit-instruction_handler
 db 'pslld',0F2h
 dw mmx_bit_shift_instruction-instruction_handler
 db 'psllq',0F3h
 dw mmx_bit_shift_instruction-instruction_handler
 db 'psllw',0F1h
 dw mmx_bit_shift_instruction-instruction_handler
 db 'psrad',0E2h
 dw mmx_bit_shift_instruction-instruction_handler
 db 'psraw',0E1h
 dw mmx_bit_shift_instruction-instruction_handler
 db 'psrld',0D2h
 dw mmx_bit_shift_instruction-instruction_handler
 db 'psrlq',0D3h
 dw mmx_bit_shift_instruction-instruction_handler
 db 'psrlw',0D1h
 dw mmx_bit_shift_instruction-instruction_handler
 db 'psubb',0F8h
 dw basic_mmx_instruction-instruction_handler
 db 'psubd',0FAh
 dw basic_mmx_instruction-instruction_handler
 db 'psubq',0FBh
 dw basic_mmx_instruction-instruction_handler
 db 'psubw',0F9h
 dw basic_mmx_instruction-instruction_handler
 db 'ptest',17h
 dw sse4_instruction_66_38-instruction_handler
 db 'pusha',60h
 dw simple_instruction_except64-instruction_handler
 db 'pushd',4
 dw push_instruction-instruction_handler
 db 'pushf',9Ch
 dw simple_instruction-instruction_handler
 db 'pushq',8
 dw push_instruction-instruction_handler
 db 'pushw',2
 dw push_instruction-instruction_handler
 db 'rcpps',53h
 dw sse_ps_instruction-instruction_handler
 db 'rcpss',53h
 dw sse_ss_instruction-instruction_handler
 db 'rdmsr',32h
 dw simple_extended_instruction-instruction_handler
 db 'rdpmc',33h
 dw simple_extended_instruction-instruction_handler
 db 'rdtsc',31h
 dw simple_extended_instruction-instruction_handler
 db 'repne',0F2h
 dw prefix_instruction-instruction_handler
 db 'repnz',0F2h
 dw prefix_instruction-instruction_handler
 db 'retfd',0CAh
 dw retf_instruction_32bit-instruction_handler
 db 'retfq',0CAh
 dw retf_instruction_64bit-instruction_handler
 db 'retfw',0CAh
 dw retf_instruction_16bit-instruction_handler
 db 'retnd',0C2h
 dw ret_instruction_32bit_except64-instruction_handler
 db 'retnq',0C2h
 dw ret_instruction_only64-instruction_handler
 db 'retnw',0C2h
 dw ret_instruction_16bit-instruction_handler
 db 'scasb',0AEh
 dw simple_instruction-instruction_handler
 db 'scasd',0AFh
 dw simple_instruction_32bit-instruction_handler
 db 'scasq',0AFh
 dw simple_instruction_64bit-instruction_handler
 db 'scasw',0AFh
 dw simple_instruction_16bit-instruction_handler
 db 'setae',93h
 dw set_instruction-instruction_handler
 db 'setbe',96h
 dw set_instruction-instruction_handler
 db 'setge',9Dh
 dw set_instruction-instruction_handler
 db 'setle',9Eh
 dw set_instruction-instruction_handler
 db 'setna',96h
 dw set_instruction-instruction_handler
 db 'setnb',93h
 dw set_instruction-instruction_handler
 db 'setnc',93h
 dw set_instruction-instruction_handler
 db 'setne',95h
 dw set_instruction-instruction_handler
 db 'setng',9Eh
 dw set_instruction-instruction_handler
 db 'setnl',9Dh
 dw set_instruction-instruction_handler
 db 'setno',91h
 dw set_instruction-instruction_handler
 db 'setnp',9Bh
 dw set_instruction-instruction_handler
 db 'setns',99h
 dw set_instruction-instruction_handler
 db 'setnz',95h
 dw set_instruction-instruction_handler
 db 'setpe',9Ah
 dw set_instruction-instruction_handler
 db 'setpo',9Bh
 dw set_instruction-instruction_handler
 db 'stack',0
 dw stack_directive-instruction_handler
 db 'store',0
 dw store_directive-instruction_handler
 db 'stosb',0AAh
 dw simple_instruction-instruction_handler
 db 'stosd',0ABh
 dw simple_instruction_32bit-instruction_handler
 db 'stosq',0ABh
 dw simple_instruction_64bit-instruction_handler
 db 'stosw',0ABh
 dw simple_instruction_16bit-instruction_handler
 db 'subpd',5Ch
 dw sse_pd_instruction-instruction_handler
 db 'subps',5Ch
 dw sse_ps_instruction-instruction_handler
 db 'subsd',5Ch
 dw sse_sd_instruction-instruction_handler
 db 'subss',5Ch
 dw sse_ss_instruction-instruction_handler
 db 'times',0
 dw times_directive-instruction_handler
 db 'tzcnt',0BCh
 dw popcnt_instruction-instruction_handler
 db 'tzmsk',14h
 dw tbm_instruction-instruction_handler
 db 'vdppd',41h
 dw avx_128bit_instruction_3a_imm8_noevex-instruction_handler
 db 'vdpps',40h
 dw avx_pi_instruction_3a_imm8_noevex-instruction_handler
 db 'vmovd',0
 dw avx_movd_instruction-instruction_handler
 db 'vmovq',0
 dw avx_movq_instruction-instruction_handler
 db 'vmrun',0D8h
 dw simple_svm_instruction-instruction_handler
 db 'vmxon',6
 dw vmxon_instruction-instruction_handler
 db 'vorpd',56h
 dw avx_pd_instruction-instruction_handler
 db 'vorps',56h
 dw avx_ps_instruction-instruction_handler
 db 'vpand',0DBh
 dw avx_pd_instruction_noevex-instruction_handler
 db 'vpord',0EBh
 dw avx_d_instruction_evex-instruction_handler
 db 'vporq',0EBh
 dw avx_q_instruction_evex-instruction_handler
 db 'vpxor',0EFh
 dw avx_pd_instruction_noevex-instruction_handler
 db 'while',0
 dw while_directive-instruction_handler
 db 'wrmsr',30h
 dw simple_extended_instruction-instruction_handler
 db 'xlatb',0D7h
 dw simple_instruction-instruction_handler
 db 'xorpd',57h
 dw sse_pd_instruction-instruction_handler
 db 'xorps',57h
 dw sse_ps_instruction-instruction_handler
 db 'xsave',100b
 dw fxsave_instruction-instruction_handler
 db 'xtest',0D6h
 dw simple_vmx_instruction-instruction_handler
instructions_6:
 db 'aesdec',0DEh
 dw sse4_instruction_66_38-instruction_handler
 db 'aesenc',0DCh
 dw sse4_instruction_66_38-instruction_handler
 db 'aesimc',0DBh
 dw sse4_instruction_66_38-instruction_handler
 db 'andnpd',55h
 dw sse_pd_instruction-instruction_handler
 db 'andnps',55h
 dw sse_ps_instruction-instruction_handler
 db 'assert',0
 dw assert_directive-instruction_handler
 db 'blcmsk',21h
 dw tbm_instruction-instruction_handler
 db 'blsmsk',2
 dw bmi_instruction-instruction_handler
 db 'bndldx',1Ah
 dw bndldx_instruction-instruction_handler
 db 'bndmov',1Ah
 dw bndmov_instruction-instruction_handler
 db 'bndstx',1Bh
 dw bndstx_instruction-instruction_handler
 db 'cmovae',43h
 dw bs_instruction-instruction_handler
 db 'cmovbe',46h
 dw bs_instruction-instruction_handler
 db 'cmovge',4Dh
 dw bs_instruction-instruction_handler
 db 'cmovle',4Eh
 dw bs_instruction-instruction_handler
 db 'cmovna',46h
 dw bs_instruction-instruction_handler
 db 'cmovnb',43h
 dw bs_instruction-instruction_handler
 db 'cmovnc',43h
 dw bs_instruction-instruction_handler
 db 'cmovne',45h
 dw bs_instruction-instruction_handler
 db 'cmovng',4Eh
 dw bs_instruction-instruction_handler
 db 'cmovnl',4Dh
 dw bs_instruction-instruction_handler
 db 'cmovno',41h
 dw bs_instruction-instruction_handler
 db 'cmovnp',4Bh
 dw bs_instruction-instruction_handler
 db 'cmovns',49h
 dw bs_instruction-instruction_handler
 db 'cmovnz',45h
 dw bs_instruction-instruction_handler
 db 'cmovpe',4Ah
 dw bs_instruction-instruction_handler
 db 'cmovpo',4Bh
 dw bs_instruction-instruction_handler
 db 'comisd',2Fh
 dw comisd_instruction-instruction_handler
 db 'comiss',2Fh
 dw comiss_instruction-instruction_handler
 db 'fcmovb',0C0h
 dw fcmov_instruction-instruction_handler
 db 'fcmove',0C8h
 dw fcmov_instruction-instruction_handler
 db 'fcmovu',0D8h
 dw fcmov_instruction-instruction_handler
 db 'fcomip',0F0h
 dw fcomip_instruction-instruction_handler
 db 'fcompp',0
 dw fcompp_instruction-instruction_handler
 db 'fdivrp',6
 dw faddp_instruction-instruction_handler
 db 'ffreep',0
 dw ffreep_instruction-instruction_handler
 db 'ficomp',3
 dw fi_instruction-instruction_handler
 db 'fidivr',7
 dw fi_instruction-instruction_handler
 db 'fisttp',1
 dw fild_instruction-instruction_handler
 db 'fisubr',5
 dw fi_instruction-instruction_handler
 db 'fldenv',4
 dw fldenv_instruction-instruction_handler
 db 'fldl2e',101010b
 dw simple_fpu_instruction-instruction_handler
 db 'fldl2t',101001b
 dw simple_fpu_instruction-instruction_handler
 db 'fldlg2',101100b
 dw simple_fpu_instruction-instruction_handler
 db 'fldln2',101101b
 dw simple_fpu_instruction-instruction_handler
 db 'fnclex',0E2h
 dw fninit_instruction-instruction_handler
 db 'fndisi',0E1h
 dw fninit_instruction-instruction_handler
 db 'fninit',0E3h
 dw fninit_instruction-instruction_handler
 db 'fnsave',6
 dw fnsave_instruction-instruction_handler
 db 'fnstcw',7
 dw fldcw_instruction-instruction_handler
 db 'fnstsw',0
 dw fnstsw_instruction-instruction_handler
 db 'format',0
 dw format_directive-instruction_handler
 db 'fpatan',110011b
 dw simple_fpu_instruction-instruction_handler
 db 'fprem1',110101b
 dw simple_fpu_instruction-instruction_handler
 db 'frstor',4
 dw fnsave_instruction-instruction_handler
 db 'frstpm',0E5h
 dw fninit_instruction-instruction_handler
 db 'fsaved',6
 dw fsave_instruction_32bit-instruction_handler
 db 'fsavew',6
 dw fsave_instruction_16bit-instruction_handler
 db 'fscale',111101b
 dw simple_fpu_instruction-instruction_handler
 db 'fsetpm',0E4h
 dw fninit_instruction-instruction_handler
 db 'fstenv',6
 dw fstenv_instruction-instruction_handler
 db 'fsubrp',4
 dw faddp_instruction-instruction_handler
 db 'fucomi',0E8h
 dw fcomi_instruction-instruction_handler
 db 'fucomp',5
 dw ffree_instruction-instruction_handler
 db 'fxsave',0
 dw fxsave_instruction-instruction_handler
 db 'getsec',37h
 dw simple_extended_instruction-instruction_handler
 db 'haddpd',07Ch
 dw sse_pd_instruction-instruction_handler
 db 'haddps',07Ch
 dw cvtpd2dq_instruction-instruction_handler
 db 'hsubpd',07Dh
 dw sse_pd_instruction-instruction_handler
 db 'hsubps',07Dh
 dw cvtpd2dq_instruction-instruction_handler
 db 'invept',80h
 dw vmx_inv_instruction-instruction_handler
 db 'invlpg',0
 dw invlpg_instruction-instruction_handler
 db 'kandnb',42h
 dw mask_instruction_b-instruction_handler
 db 'kandnd',42h
 dw mask_instruction_d-instruction_handler
 db 'kandnq',42h
 dw mask_instruction_q-instruction_handler
 db 'kandnw',42h
 dw mask_instruction_w-instruction_handler
 db 'ktestb',99h
 dw mask_instruction_single_source_b-instruction_handler
 db 'ktestd',99h
 dw mask_instruction_single_source_d-instruction_handler
 db 'ktestq',99h
 dw mask_instruction_single_source_q-instruction_handler
 db 'ktestw',99h
 dw mask_instruction_single_source_w-instruction_handler
 db 'kxnorb',46h
 dw mask_instruction_b-instruction_handler
 db 'kxnord',46h
 dw mask_instruction_d-instruction_handler
 db 'kxnorq',46h
 dw mask_instruction_q-instruction_handler
 db 'kxnorw',46h
 dw mask_instruction_w-instruction_handler
 db 'lfence',0E8h
 dw fence_instruction-instruction_handler
 db 'llwpcb',0
 dw llwpcb_instruction-instruction_handler
 db 'looped',0E1h
 dw loop_instruction_32bit-instruction_handler
 db 'loopeq',0E1h
 dw loop_instruction_64bit-instruction_handler
 db 'loopew',0E1h
 dw loop_instruction_16bit-instruction_handler
 db 'loopne',0E0h
 dw loop_instruction-instruction_handler
 db 'loopnz',0E0h
 dw loop_instruction-instruction_handler
 db 'loopzd',0E1h
 dw loop_instruction_32bit-instruction_handler
 db 'loopzq',0E1h
 dw loop_instruction_64bit-instruction_handler
 db 'loopzw',0E1h
 dw loop_instruction_16bit-instruction_handler
 db 'lwpins',0
 dw lwpins_instruction-instruction_handler
 db 'lwpval',1
 dw lwpins_instruction-instruction_handler
 db 'mfence',0F0h
 dw fence_instruction-instruction_handler
 db 'movapd',28h
 dw movpd_instruction-instruction_handler
 db 'movaps',28h
 dw movps_instruction-instruction_handler
 db 'movdqa',66h
 dw movdq_instruction-instruction_handler
 db 'movdqu',0F3h
 dw movdq_instruction-instruction_handler
 db 'movhpd',16h
 dw movlpd_instruction-instruction_handler
 db 'movhps',16h
 dw movlps_instruction-instruction_handler
 db 'movlpd',12h
 dw movlpd_instruction-instruction_handler
 db 'movlps',12h
 dw movlps_instruction-instruction_handler
 db 'movnti',0C3h
 dw movnti_instruction-instruction_handler
 db 'movntq',0E7h
 dw movntq_instruction-instruction_handler
 db 'movsxd',63h
 dw movsxd_instruction-instruction_handler
 db 'movupd',10h
 dw movpd_instruction-instruction_handler
 db 'movups',10h
 dw movps_instruction-instruction_handler
 db 'paddsb',0ECh
 dw basic_mmx_instruction-instruction_handler
 db 'paddsw',0EDh
 dw basic_mmx_instruction-instruction_handler
 db 'pextrb',14h
 dw pextrb_instruction-instruction_handler
 db 'pextrd',16h
 dw pextrd_instruction-instruction_handler
 db 'pextrq',16h
 dw pextrq_instruction-instruction_handler
 db 'pextrw',15h
 dw pextrw_instruction-instruction_handler
 db 'pfnacc',8Ah
 dw amd3dnow_instruction-instruction_handler
 db 'pfsubr',0AAh
 dw amd3dnow_instruction-instruction_handler
 db 'phaddd',2
 dw ssse3_instruction-instruction_handler
 db 'phaddw',1
 dw ssse3_instruction-instruction_handler
 db 'phsubd',6
 dw ssse3_instruction-instruction_handler
 db 'phsubw',5
 dw ssse3_instruction-instruction_handler
 db 'pinsrb',20h
 dw pinsrb_instruction-instruction_handler
 db 'pinsrd',22h
 dw pinsrd_instruction-instruction_handler
 db 'pinsrq',22h
 dw pinsrq_instruction-instruction_handler
 db 'pinsrw',0C4h
 dw pinsrw_instruction-instruction_handler
 db 'pmaxsb',3Ch
 dw sse4_instruction_66_38-instruction_handler
 db 'pmaxsd',3Dh
 dw sse4_instruction_66_38-instruction_handler
 db 'pmaxsw',0EEh
 dw basic_mmx_instruction-instruction_handler
 db 'pmaxub',0DEh
 dw basic_mmx_instruction-instruction_handler
 db 'pmaxud',3Fh
 dw sse4_instruction_66_38-instruction_handler
 db 'pmaxuw',3Eh
 dw sse4_instruction_66_38-instruction_handler
 db 'pminsb',38h
 dw sse4_instruction_66_38-instruction_handler
 db 'pminsd',39h
 dw sse4_instruction_66_38-instruction_handler
 db 'pminsw',0EAh
 dw basic_mmx_instruction-instruction_handler
 db 'pminub',0DAh
 dw basic_mmx_instruction-instruction_handler
 db 'pminud',comment_marker
 dw sse4_instruction_66_38-instruction_handler
 db 'pminuw',3Ah
 dw sse4_instruction_66_38-instruction_handler
 db 'pmuldq',28h
 dw sse4_instruction_66_38-instruction_handler
 db 'pmulhw',0E5h
 dw basic_mmx_instruction-instruction_handler
 db 'pmulld',40h
 dw sse4_instruction_66_38-instruction_handler
 db 'pmullw',0D5h
 dw basic_mmx_instruction-instruction_handler
 db 'popcnt',0B8h
 dw popcnt_instruction-instruction_handler
 db 'psadbw',0F6h
 dw basic_mmx_instruction-instruction_handler
 db 'pshufb',0
 dw ssse3_instruction-instruction_handler
 db 'pshufd',66h
 dw pshufd_instruction-instruction_handler
 db 'pshufw',0
 dw pshufw_instruction-instruction_handler
 db 'psignb',8
 dw ssse3_instruction-instruction_handler
 db 'psignd',0Ah
 dw ssse3_instruction-instruction_handler
 db 'psignw',9
 dw ssse3_instruction-instruction_handler
 db 'pslldq',111b
 dw pslldq_instruction-instruction_handler
 db 'psrldq',011b
 dw pslldq_instruction-instruction_handler
 db 'psubsb',0E8h
 dw basic_mmx_instruction-instruction_handler
 db 'psubsw',0E9h
 dw basic_mmx_instruction-instruction_handler
 db 'pswapd',0BBh
 dw amd3dnow_instruction-instruction_handler
 db 'public',0
 dw public_directive-instruction_handler
 db 'pushad',60h
 dw simple_instruction_32bit_except64-instruction_handler
 db 'pushaw',60h
 dw simple_instruction_16bit_except64-instruction_handler
 db 'pushfd',9Ch
 dw simple_instruction_32bit_except64-instruction_handler
 db 'pushfq',9Ch
 dw simple_instruction_only64-instruction_handler
 db 'pushfw',9Ch
 dw simple_instruction_16bit-instruction_handler
 db 'rdmsrq',32h
 dw simple_extended_instruction_64bit-instruction_handler
 db 'rdrand',110b
 dw rdrand_instruction-instruction_handler
 db 'rdseed',111b
 dw rdrand_instruction-instruction_handler
 db 'rdtscp',1
 dw rdtscp_instruction-instruction_handler
 db 'repeat',0
 dw repeat_directive-instruction_handler
 db 'setalc',0D6h
 dw simple_instruction_except64-instruction_handler
 db 'setnae',92h
 dw set_instruction-instruction_handler
 db 'setnbe',97h
 dw set_instruction-instruction_handler
 db 'setnge',9Ch
 dw set_instruction-instruction_handler
 db 'setnle',9Fh
 dw set_instruction-instruction_handler
 db 'sfence',0F8h
 dw fence_instruction-instruction_handler
 db 'shufpd',0C6h
 dw sse_pd_instruction_imm8-instruction_handler
 db 'shufps',0C6h
 dw sse_ps_instruction_imm8-instruction_handler
 db 'skinit',0
 dw skinit_instruction-instruction_handler
 db 'slwpcb',1
 dw llwpcb_instruction-instruction_handler
 db 'sqrtpd',51h
 dw sse_pd_instruction-instruction_handler
 db 'sqrtps',51h
 dw sse_ps_instruction-instruction_handler
 db 'sqrtsd',51h
 dw sse_sd_instruction-instruction_handler
 db 'sqrtss',51h
 dw sse_ss_instruction-instruction_handler
 db 'swapgs',0
 dw swapgs_instruction-instruction_handler
 db 'sysret',07h
 dw simple_extended_instruction-instruction_handler
 db 't1mskc',17h
 dw tbm_instruction-instruction_handler
 db 'vaddpd',58h
 dw avx_pd_instruction_er-instruction_handler
 db 'vaddps',58h
 dw avx_ps_instruction_er-instruction_handler
 db 'vaddsd',58h
 dw avx_sd_instruction_er-instruction_handler
 db 'vaddss',58h
 dw avx_ss_instruction_er-instruction_handler
 db 'vandpd',54h
 dw avx_pd_instruction-instruction_handler
 db 'vandps',54h
 dw avx_ps_instruction-instruction_handler
 db 'vcmppd',-1
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpps',-1
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpsd',-1
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpss',-1
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vdivpd',5Eh
 dw avx_pd_instruction_er-instruction_handler
 db 'vdivps',5Eh
 dw avx_ps_instruction_er-instruction_handler
 db 'vdivsd',5Eh
 dw avx_sd_instruction_er-instruction_handler
 db 'vdivss',5Eh
 dw avx_ss_instruction_er-instruction_handler
 db 'vlddqu',0F0h
 dw avx_lddqu_instruction-instruction_handler
 db 'vmaxpd',5Fh
 dw avx_pd_instruction_sae-instruction_handler
 db 'vmaxps',5Fh
 dw avx_ps_instruction_sae-instruction_handler
 db 'vmaxsd',5Fh
 dw avx_sd_instruction_sae-instruction_handler
 db 'vmaxss',5Fh
 dw avx_ss_instruction_sae-instruction_handler
 db 'vmcall',0C1h
 dw simple_vmx_instruction-instruction_handler
 db 'vminpd',5Dh
 dw avx_pd_instruction_sae-instruction_handler
 db 'vminps',5Dh
 dw avx_ps_instruction_sae-instruction_handler
 db 'vminsd',5Dh
 dw avx_sd_instruction_sae-instruction_handler
 db 'vminss',5Dh
 dw avx_ss_instruction_sae-instruction_handler
 db 'vmload',0DAh
 dw simple_svm_instruction-instruction_handler
 db 'vmovsd',0
 dw avx_movsd_instruction-instruction_handler
 db 'vmovss',0
 dw avx_movss_instruction-instruction_handler
 db 'vmread',0
 dw vmread_instruction-instruction_handler
 db 'vmsave',0DBh
 dw simple_svm_instruction-instruction_handler
 db 'vmulpd',59h
 dw avx_pd_instruction_er-instruction_handler
 db 'vmulps',59h
 dw avx_ps_instruction_er-instruction_handler
 db 'vmulsd',59h
 dw avx_sd_instruction_er-instruction_handler
 db 'vmulss',59h
 dw avx_ss_instruction_er-instruction_handler
 db 'vmxoff',0C4h
 dw simple_vmx_instruction-instruction_handler
 db 'vpabsb',1Ch
 dw avx_single_source_bw_instruction_38-instruction_handler
 db 'vpabsd',1Eh
 dw avx_single_source_d_instruction_38-instruction_handler
 db 'vpabsq',1Fh
 dw avx_single_source_q_instruction_38_evex-instruction_handler
 db 'vpabsw',1Dh
 dw avx_single_source_bw_instruction_38-instruction_handler
 db 'vpaddb',0FCh
 dw avx_bw_instruction-instruction_handler
 db 'vpaddd',0FEh
 dw avx_d_instruction-instruction_handler
 db 'vpaddq',0D4h
 dw avx_q_instruction-instruction_handler
 db 'vpaddw',0FDh
 dw avx_bw_instruction-instruction_handler
 db 'vpandd',0DBh
 dw avx_d_instruction_evex-instruction_handler
 db 'vpandn',0DFh
 dw avx_pd_instruction_noevex-instruction_handler
 db 'vpandq',0DBh
 dw avx_q_instruction_evex-instruction_handler
 db 'vpavgb',0E0h
 dw avx_bw_instruction-instruction_handler
 db 'vpavgw',0E3h
 dw avx_bw_instruction-instruction_handler
 db 'vpcmov',0A2h
 dw vpcmov_instruction-instruction_handler
 db 'vpcmpb',-1
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcmpd',-1
 dw avx512_cmp_d_instruction-instruction_handler
 db 'vpcmpq',-1
 dw avx512_cmp_q_instruction-instruction_handler
 db 'vpcmpw',-1
 dw avx512_cmp_w_instruction-instruction_handler
 db 'vpcomb',-1
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomd',-1
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomq',-1
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomw',-1
 dw xop_pcom_w_instruction-instruction_handler
 db 'vpermb',8Dh
 dw avx_bw_instruction_38_evex-instruction_handler
 db 'vpermd',36h
 dw avx_permd_instruction-instruction_handler
 db 'vpermq',0
 dw avx_permq_instruction-instruction_handler
 db 'vpermw',8Dh
 dw avx_bw_instruction_38_w1_evex-instruction_handler
 db 'vpperm',0A3h
 dw xop_128bit_instruction-instruction_handler
 db 'vprold',1
 dw avx512_rotate_d_instruction-instruction_handler
 db 'vprolq',1
 dw avx512_rotate_q_instruction-instruction_handler
 db 'vprord',0
 dw avx512_rotate_d_instruction-instruction_handler
 db 'vprorq',0
 dw avx512_rotate_q_instruction-instruction_handler
 db 'vprotb',90h
 dw xop_shift_instruction-instruction_handler
 db 'vprotd',92h
 dw xop_shift_instruction-instruction_handler
 db 'vprotq',93h
 dw xop_shift_instruction-instruction_handler
 db 'vprotw',91h
 dw xop_shift_instruction-instruction_handler
 db 'vpshab',98h
 dw xop_shift_instruction-instruction_handler
 db 'vpshad',9Ah
 dw xop_shift_instruction-instruction_handler
 db 'vpshaq',9Bh
 dw xop_shift_instruction-instruction_handler
 db 'vpshaw',99h
 dw xop_shift_instruction-instruction_handler
 db 'vpshlb',94h
 dw xop_shift_instruction-instruction_handler
 db 'vpshld',96h
 dw xop_shift_instruction-instruction_handler
 db 'vpshlq',97h
 dw xop_shift_instruction-instruction_handler
 db 'vpshlw',95h
 dw xop_shift_instruction-instruction_handler
 db 'vpslld',0F2h
 dw avx_shift_d_instruction-instruction_handler
 db 'vpsllq',0F3h
 dw avx_shift_q_instruction-instruction_handler
 db 'vpsllw',0F1h
 dw avx_shift_bw_instruction-instruction_handler
 db 'vpsrad',0E2h
 dw avx_shift_d_instruction-instruction_handler
 db 'vpsraq',0E2h
 dw avx_shift_q_instruction_evex-instruction_handler
 db 'vpsraw',0E1h
 dw avx_shift_bw_instruction-instruction_handler
 db 'vpsrld',0D2h
 dw avx_shift_d_instruction-instruction_handler
 db 'vpsrlq',0D3h
 dw avx_shift_q_instruction-instruction_handler
 db 'vpsrlw',0D1h
 dw avx_shift_bw_instruction-instruction_handler
 db 'vpsubb',0F8h
 dw avx_bw_instruction-instruction_handler
 db 'vpsubd',0FAh
 dw avx_d_instruction-instruction_handler
 db 'vpsubq',0FBh
 dw avx_q_instruction-instruction_handler
 db 'vpsubw',0F9h
 dw avx_bw_instruction-instruction_handler
 db 'vptest',17h
 dw avx_single_source_instruction_38_noevex-instruction_handler
 db 'vpxord',0EFh
 dw avx_d_instruction_evex-instruction_handler
 db 'vpxorq',0EFh
 dw avx_q_instruction_evex-instruction_handler
 db 'vrcpps',53h
 dw avx_single_source_ps_instruction_noevex-instruction_handler
 db 'vrcpss',53h
 dw avx_ss_instruction_noevex-instruction_handler
 db 'vsubpd',5Ch
 dw avx_pd_instruction_er-instruction_handler
 db 'vsubps',5Ch
 dw avx_ps_instruction_er-instruction_handler
 db 'vsubsd',5Ch
 dw avx_sd_instruction_er-instruction_handler
 db 'vsubss',5Ch
 dw avx_ss_instruction_er-instruction_handler
 db 'vxorpd',57h
 dw avx_pd_instruction-instruction_handler
 db 'vxorps',57h
 dw avx_ps_instruction-instruction_handler
 db 'wbinvd',9
 dw simple_extended_instruction-instruction_handler
 db 'wrmsrq',30h
 dw simple_extended_instruction_64bit-instruction_handler
 db 'xabort',0
 dw xabort_instruction-instruction_handler
 db 'xbegin',0
 dw xbegin_instruction-instruction_handler
 db 'xgetbv',0D0h
 dw simple_vmx_instruction-instruction_handler
 db 'xrstor',101b
 dw fxsave_instruction-instruction_handler
 db 'xsetbv',0D1h
 dw simple_vmx_instruction-instruction_handler
instructions_7:
 db 'blcfill',11h
 dw tbm_instruction-instruction_handler
 db 'blendpd',0Dh
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'blendps',0Ch
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'blsfill',12h
 dw tbm_instruction-instruction_handler
 db 'clflush',111b
 dw fxsave_instruction-instruction_handler
 db 'cmovnae',42h
 dw bs_instruction-instruction_handler
 db 'cmovnbe',47h
 dw bs_instruction-instruction_handler
 db 'cmovnge',4Ch
 dw bs_instruction-instruction_handler
 db 'cmovnle',4Fh
 dw bs_instruction-instruction_handler
 db 'cmpeqpd',0
 dw cmp_pd_instruction-instruction_handler
 db 'cmpeqps',0
 dw cmp_ps_instruction-instruction_handler
 db 'cmpeqsd',0
 dw cmp_sd_instruction-instruction_handler
 db 'cmpeqss',0
 dw cmp_ss_instruction-instruction_handler
 db 'cmplepd',2
 dw cmp_pd_instruction-instruction_handler
 db 'cmpleps',2
 dw cmp_ps_instruction-instruction_handler
 db 'cmplesd',2
 dw cmp_sd_instruction-instruction_handler
 db 'cmpless',2
 dw cmp_ss_instruction-instruction_handler
 db 'cmpltpd',1
 dw cmp_pd_instruction-instruction_handler
 db 'cmpltps',1
 dw cmp_ps_instruction-instruction_handler
 db 'cmpltsd',1
 dw cmp_sd_instruction-instruction_handler
 db 'cmpltss',1
 dw cmp_ss_instruction-instruction_handler
 db 'cmpxchg',0B0h
 dw basic_486_instruction-instruction_handler
 db 'display',0
 dw display_directive-instruction_handler
 db 'fcmovbe',0D0h
 dw fcmov_instruction-instruction_handler
 db 'fcmovnb',0C0h
 dw fcomi_instruction-instruction_handler
 db 'fcmovne',0C8h
 dw fcomi_instruction-instruction_handler
 db 'fcmovnu',0D8h
 dw fcomi_instruction-instruction_handler
 db 'fdecstp',110110b
 dw simple_fpu_instruction-instruction_handler
 db 'fincstp',110111b
 dw simple_fpu_instruction-instruction_handler
 db 'fldenvd',4
 dw fldenv_instruction_32bit-instruction_handler
 db 'fldenvw',4
 dw fldenv_instruction_16bit-instruction_handler
 db 'fnsaved',6
 dw fnsave_instruction_32bit-instruction_handler
 db 'fnsavew',6
 dw fnsave_instruction_16bit-instruction_handler
 db 'fnstenv',6
 dw fldenv_instruction-instruction_handler
 db 'frndint',111100b
 dw simple_fpu_instruction-instruction_handler
 db 'frstord',4
 dw fnsave_instruction_32bit-instruction_handler
 db 'frstorw',4
 dw fnsave_instruction_16bit-instruction_handler
 db 'fsincos',111011b
 dw simple_fpu_instruction-instruction_handler
 db 'fstenvd',6
 dw fstenv_instruction_32bit-instruction_handler
 db 'fstenvw',6
 dw fstenv_instruction_16bit-instruction_handler
 db 'fucomip',0E8h
 dw fcomip_instruction-instruction_handler
 db 'fucompp',0
 dw fucompp_instruction-instruction_handler
 db 'fxrstor',1
 dw fxsave_instruction-instruction_handler
 db 'fxtract',110100b
 dw simple_fpu_instruction-instruction_handler
 db 'fyl2xp1',111001b
 dw simple_fpu_instruction-instruction_handler
 db 'insertq',0
 dw insertq_instruction-instruction_handler
 db 'invlpga',0DFh
 dw invlpga_instruction-instruction_handler
 db 'invpcid',82h
 dw vmx_inv_instruction-instruction_handler
 db 'invvpid',81h
 dw vmx_inv_instruction-instruction_handler
 db 'ldmxcsr',10b
 dw fxsave_instruction-instruction_handler
 db 'loopned',0E0h
 dw loop_instruction_32bit-instruction_handler
 db 'loopneq',0E0h
 dw loop_instruction_64bit-instruction_handler
 db 'loopnew',0E0h
 dw loop_instruction_16bit-instruction_handler
 db 'loopnzd',0E0h
 dw loop_instruction_32bit-instruction_handler
 db 'loopnzq',0E0h
 dw loop_instruction_64bit-instruction_handler
 db 'loopnzw',0E0h
 dw loop_instruction_16bit-instruction_handler
 db 'monitor',0C8h
 dw monitor_instruction-instruction_handler
 db 'movddup',12h
 dw sse_sd_instruction-instruction_handler
 db 'movdq2q',0
 dw movdq2q_instruction-instruction_handler
 db 'movhlps',12h
 dw movhlps_instruction-instruction_handler
 db 'movlhps',16h
 dw movhlps_instruction-instruction_handler
 db 'movntdq',0E7h
 dw movntpd_instruction-instruction_handler
 db 'movntpd',2Bh
 dw movntpd_instruction-instruction_handler
 db 'movntps',2Bh
 dw movntps_instruction-instruction_handler
 db 'movntsd',2Bh
 dw movntsd_instruction-instruction_handler
 db 'movntss',2Bh
 dw movntss_instruction-instruction_handler
 db 'movq2dq',0
 dw movq2dq_instruction-instruction_handler
 db 'mpsadbw',42h
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'paddusb',0DCh
 dw basic_mmx_instruction-instruction_handler
 db 'paddusw',0DDh
 dw basic_mmx_instruction-instruction_handler
 db 'palignr',0
 dw palignr_instruction-instruction_handler
 db 'pavgusb',0BFh
 dw amd3dnow_instruction-instruction_handler
 db 'pblendw',0Eh
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'pcmpeqb',74h
 dw basic_mmx_instruction-instruction_handler
 db 'pcmpeqd',76h
 dw basic_mmx_instruction-instruction_handler
 db 'pcmpeqq',29h
 dw sse4_instruction_66_38-instruction_handler
 db 'pcmpeqw',75h
 dw basic_mmx_instruction-instruction_handler
 db 'pcmpgtb',64h
 dw basic_mmx_instruction-instruction_handler
 db 'pcmpgtd',66h
 dw basic_mmx_instruction-instruction_handler
 db 'pcmpgtq',37h
 dw sse4_instruction_66_38-instruction_handler
 db 'pcmpgtw',65h
 dw basic_mmx_instruction-instruction_handler
 db 'pcommit',0F8h
 dw pcommit_instruction-instruction_handler
 db 'pfcmpeq',0B0h
 dw amd3dnow_instruction-instruction_handler
 db 'pfcmpge',90h
 dw amd3dnow_instruction-instruction_handler
 db 'pfcmpgt',0A0h
 dw amd3dnow_instruction-instruction_handler
 db 'pfpnacc',8Eh
 dw amd3dnow_instruction-instruction_handler
 db 'pfrsqrt',97h
 dw amd3dnow_instruction-instruction_handler
 db 'phaddsw',3
 dw ssse3_instruction-instruction_handler
 db 'phsubsw',7
 dw ssse3_instruction-instruction_handler
 db 'pmaddwd',0F5h
 dw basic_mmx_instruction-instruction_handler
 db 'pmulhrw',0B7h
 dw amd3dnow_instruction-instruction_handler
 db 'pmulhuw',0E4h
 dw basic_mmx_instruction-instruction_handler
 db 'pmuludq',0F4h
 dw basic_mmx_instruction-instruction_handler
 db 'pshufhw',0F3h
 dw pshufd_instruction-instruction_handler
 db 'pshuflw',0F2h
 dw pshufd_instruction-instruction_handler
 db 'psubusb',0D8h
 dw basic_mmx_instruction-instruction_handler
 db 'psubusw',0D9h
 dw basic_mmx_instruction-instruction_handler
 db 'roundpd',9
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'roundps',8
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'roundsd',0Bh
 dw sse4_sd_instruction_66_3a_imm8-instruction_handler
 db 'roundss',0Ah
 dw sse4_ss_instruction_66_3a_imm8-instruction_handler
 db 'rsqrtps',52h
 dw sse_ps_instruction-instruction_handler
 db 'rsqrtss',52h
 dw sse_ss_instruction-instruction_handler
 db 'section',0
 dw section_directive-instruction_handler
 db 'segment',0
 dw segment_directive-instruction_handler
 db 'stmxcsr',11b
 dw fxsave_instruction-instruction_handler
 db 'syscall',05h
 dw simple_extended_instruction-instruction_handler
 db 'sysexit',35h
 dw simple_extended_instruction-instruction_handler
 db 'sysretq',07h
 dw simple_extended_instruction_64bit-instruction_handler
 db 'ucomisd',2Eh
 dw comisd_instruction-instruction_handler
 db 'ucomiss',2Eh
 dw comiss_instruction-instruction_handler
 db 'vaesdec',0DEh
 dw avx_128bit_instruction_38_noevex-instruction_handler
 db 'vaesenc',0DCh
 dw avx_128bit_instruction_38_noevex-instruction_handler
 db 'vaesimc',0DBh
 dw avx_single_source_128bit_instruction_38_noevex-instruction_handler
 db 'valignd',3
 dw avx_d_instruction_3a_imm8_evex-instruction_handler
 db 'valignq',3
 dw avx_q_instruction_3a_imm8_evex-instruction_handler
 db 'vandnpd',55h
 dw avx_pd_instruction-instruction_handler
 db 'vandnps',55h
 dw avx_ps_instruction-instruction_handler
 db 'vcomisd',2Fh
 dw avx_comisd_instruction-instruction_handler
 db 'vcomiss',2Fh
 dw avx_comiss_instruction-instruction_handler
 db 'vexp2pd',0C8h
 dw avx512_exp2pd_instruction-instruction_handler
 db 'vexp2ps',0C8h
 dw avx512_exp2ps_instruction-instruction_handler
 db 'vfrczpd',81h
 dw xop_single_source_instruction-instruction_handler
 db 'vfrczps',80h
 dw xop_single_source_instruction-instruction_handler
 db 'vfrczsd',83h
 dw xop_single_source_sd_instruction-instruction_handler
 db 'vfrczss',82h
 dw xop_single_source_ss_instruction-instruction_handler
 db 'vhaddpd',07Ch
 dw avx_pd_instruction_noevex-instruction_handler
 db 'vhaddps',07Ch
 dw avx_ps_instruction_noevex-instruction_handler
 db 'vhsubpd',07Dh
 dw avx_pd_instruction_noevex-instruction_handler
 db 'vhsubps',07Dh
 dw avx_ps_instruction_noevex-instruction_handler
 db 'virtual',0
 dw virtual_directive-instruction_handler
 db 'vmclear',6
 dw vmclear_instruction-instruction_handler
 db 'vmmcall',0D9h
 dw simple_vmx_instruction-instruction_handler
 db 'vmovapd',28h
 dw avx_movpd_instruction-instruction_handler
 db 'vmovaps',28h
 dw avx_movps_instruction-instruction_handler
 db 'vmovdqa',6Fh
 dw avx_movdqa_instruction-instruction_handler
 db 'vmovdqu',6Fh
 dw avx_movdqu_instruction-instruction_handler
 db 'vmovhpd',16h
 dw avx_movlpd_instruction-instruction_handler
 db 'vmovhps',16h
 dw avx_movlps_instruction-instruction_handler
 db 'vmovlpd',12h
 dw avx_movlpd_instruction-instruction_handler
 db 'vmovlps',12h
 dw avx_movlps_instruction-instruction_handler
 db 'vmovupd',10h
 dw avx_movpd_instruction-instruction_handler
 db 'vmovups',10h
 dw avx_movps_instruction-instruction_handler
 db 'vmptrld',6
 dw vmx_instruction-instruction_handler
 db 'vmptrst',7
 dw vmx_instruction-instruction_handler
 db 'vmwrite',0
 dw vmwrite_instruction-instruction_handler
 db 'vpaddsb',0ECh
 dw avx_bw_instruction-instruction_handler
 db 'vpaddsw',0EDh
 dw avx_bw_instruction-instruction_handler
 db 'vpandnd',0DFh
 dw avx_d_instruction_evex-instruction_handler
 db 'vpandnq',0DFh
 dw avx_q_instruction_evex-instruction_handler
 db 'vpcmpub',-1
 dw avx512_cmp_ub_instruction-instruction_handler
 db 'vpcmpud',-1
 dw avx512_cmp_ud_instruction-instruction_handler
 db 'vpcmpuq',-1
 dw avx512_cmp_uq_instruction-instruction_handler
 db 'vpcmpuw',-1
 dw avx512_cmp_uw_instruction-instruction_handler
 db 'vpcomub',-1
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomud',-1
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomuq',-1
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomuw',-1
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpermpd',1
 dw avx_permq_instruction-instruction_handler
 db 'vpermps',16h
 dw avx_permd_instruction-instruction_handler
 db 'vpextrb',14h
 dw avx_extract_b_instruction-instruction_handler
 db 'vpextrd',16h
 dw avx_extract_d_instruction-instruction_handler
 db 'vpextrq',16h
 dw avx_extract_q_instruction-instruction_handler
 db 'vpextrw',15h
 dw avx_extract_w_instruction-instruction_handler
 db 'vphaddd',2
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vphaddw',1
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vphsubd',6
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vphsubw',5
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vpinsrb',20h
 dw avx_pinsrb_instruction-instruction_handler
 db 'vpinsrd',22h
 dw avx_pinsrd_instruction-instruction_handler
 db 'vpinsrq',22h
 dw avx_pinsrq_instruction-instruction_handler
 db 'vpinsrw',0C4h
 dw avx_pinsrw_instruction-instruction_handler
 db 'vpmaxsb',3Ch
 dw avx_bw_instruction_38-instruction_handler
 db 'vpmaxsd',3Dh
 dw avx_d_instruction_38-instruction_handler
 db 'vpmaxsq',3Dh
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpmaxsw',0EEh
 dw avx_bw_instruction-instruction_handler
 db 'vpmaxub',0DEh
 dw avx_bw_instruction-instruction_handler
 db 'vpmaxud',3Fh
 dw avx_d_instruction_38-instruction_handler
 db 'vpmaxuq',3Fh
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpmaxuw',3Eh
 dw avx_bw_instruction_38-instruction_handler
 db 'vpminsb',38h
 dw avx_bw_instruction_38-instruction_handler
 db 'vpminsd',39h
 dw avx_d_instruction_38-instruction_handler
 db 'vpminsq',39h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpminsw',0EAh
 dw avx_bw_instruction-instruction_handler
 db 'vpminub',0DAh
 dw avx_bw_instruction-instruction_handler
 db 'vpminud',comment_marker
 dw avx_d_instruction_38-instruction_handler
 db 'vpminuq',comment_marker
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpminuw',3Ah
 dw avx_bw_instruction_38-instruction_handler
 db 'vpmovdb',31h
 dw avx512_pmovdb_instruction-instruction_handler
 db 'vpmovdw',33h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmovqb',32h
 dw avx512_pmovqb_instruction-instruction_handler
 db 'vpmovqd',35h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmovqw',34h
 dw avx512_pmovdb_instruction-instruction_handler
 db 'vpmovwb',30h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmuldq',28h
 dw avx_q_instruction_38-instruction_handler
 db 'vpmulhw',0E5h
 dw avx_bw_instruction-instruction_handler
 db 'vpmulld',40h
 dw avx_d_instruction_38-instruction_handler
 db 'vpmullq',40h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpmullw',0D5h
 dw avx_bw_instruction-instruction_handler
 db 'vprolvd',15h
 dw avx_d_instruction_38_evex-instruction_handler
 db 'vprolvq',15h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vprorvd',14h
 dw avx_d_instruction_38_evex-instruction_handler
 db 'vprorvq',14h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpsadbw',0F6h
 dw avx_bw_instruction-instruction_handler
 db 'vpshufb',0
 dw avx_bw_instruction_38-instruction_handler
 db 'vpshufd',70h
 dw avx_single_source_d_instruction_imm8-instruction_handler
 db 'vpsignb',8
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vpsignd',0Ah
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vpsignw',9
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vpslldq',111b
 dw avx_shift_dq_instruction-instruction_handler
 db 'vpsllvd',47h
 dw avx_d_instruction_38-instruction_handler
 db 'vpsllvq',47h
 dw avx_q_instruction_38_w1-instruction_handler
 db 'vpsllvw',12h
 dw avx_bw_instruction_38_w1_evex-instruction_handler
 db 'vpsravd',46h
 dw avx_d_instruction_38-instruction_handler
 db 'vpsravq',46h
 dw avx_q_instruction_38_w1_evex-instruction_handler
 db 'vpsravw',11h
 dw avx_bw_instruction_38_w1_evex-instruction_handler
 db 'vpsrldq',011b
 dw avx_shift_dq_instruction-instruction_handler
 db 'vpsrlvd',45h
 dw avx_d_instruction_38-instruction_handler
 db 'vpsrlvq',45h
 dw avx_q_instruction_38_w1-instruction_handler
 db 'vpsrlvw',10h
 dw avx_bw_instruction_38_w1_evex-instruction_handler
 db 'vpsubsb',0E8h
 dw avx_bw_instruction-instruction_handler
 db 'vpsubsw',0E9h
 dw avx_bw_instruction-instruction_handler
 db 'vshufpd',0C6h
 dw avx_pd_instruction_imm8-instruction_handler
 db 'vshufps',0C6h
 dw avx_ps_instruction_imm8-instruction_handler
 db 'vsqrtpd',51h
 dw avx_single_source_pd_instruction_er-instruction_handler
 db 'vsqrtps',51h
 dw avx_single_source_ps_instruction_er-instruction_handler
 db 'vsqrtsd',51h
 dw avx_sd_instruction_er-instruction_handler
 db 'vsqrtss',51h
 dw avx_ss_instruction_er-instruction_handler
 db 'vtestpd',0Fh
 dw avx_single_source_instruction_38_noevex-instruction_handler
 db 'vtestps',0Eh
 dw avx_single_source_instruction_38_noevex-instruction_handler
 db 'xsave64',100b
 dw fxsave_instruction_64bit-instruction_handler
instructions_8:
 db 'addsubpd',0D0h
 dw sse_pd_instruction-instruction_handler
 db 'addsubps',0D0h
 dw cvtpd2dq_instruction-instruction_handler
 db 'blendvpd',15h
 dw sse4_instruction_66_38_xmm0-instruction_handler
 db 'blendvps',14h
 dw sse4_instruction_66_38_xmm0-instruction_handler
 db 'cmpneqpd',4
 dw cmp_pd_instruction-instruction_handler
 db 'cmpneqps',4
 dw cmp_ps_instruction-instruction_handler
 db 'cmpneqsd',4
 dw cmp_sd_instruction-instruction_handler
 db 'cmpneqss',4
 dw cmp_ss_instruction-instruction_handler
 db 'cmpnlepd',6
 dw cmp_pd_instruction-instruction_handler
 db 'cmpnleps',6
 dw cmp_ps_instruction-instruction_handler
 db 'cmpnlesd',6
 dw cmp_sd_instruction-instruction_handler
 db 'cmpnless',6
 dw cmp_ss_instruction-instruction_handler
 db 'cmpnltpd',5
 dw cmp_pd_instruction-instruction_handler
 db 'cmpnltps',5
 dw cmp_ps_instruction-instruction_handler
 db 'cmpnltsd',5
 dw cmp_sd_instruction-instruction_handler
 db 'cmpnltss',5
 dw cmp_ss_instruction-instruction_handler
 db 'cmpordpd',7
 dw cmp_pd_instruction-instruction_handler
 db 'cmpordps',7
 dw cmp_ps_instruction-instruction_handler
 db 'cmpordsd',7
 dw cmp_sd_instruction-instruction_handler
 db 'cmpordss',7
 dw cmp_ss_instruction-instruction_handler
 db 'cvtdq2pd',0E6h
 dw cvtdq2pd_instruction-instruction_handler
 db 'cvtdq2ps',5Bh
 dw sse_ps_instruction-instruction_handler
 db 'cvtpd2dq',0E6h
 dw cvtpd2dq_instruction-instruction_handler
 db 'cvtpd2pi',2Dh
 dw cvtpd2pi_instruction-instruction_handler
 db 'cvtpd2ps',5Ah
 dw sse_pd_instruction-instruction_handler
 db 'cvtpi2pd',2Ah
 dw cvtpi2pd_instruction-instruction_handler
 db 'cvtpi2ps',2Ah
 dw cvtpi2ps_instruction-instruction_handler
 db 'cvtps2dq',5Bh
 dw sse_pd_instruction-instruction_handler
 db 'cvtps2pd',5Ah
 dw cvtps2pd_instruction-instruction_handler
 db 'cvtps2pi',2Dh
 dw cvtps2pi_instruction-instruction_handler
 db 'cvtsd2si',2Dh
 dw cvtsd2si_instruction-instruction_handler
 db 'cvtsd2ss',5Ah
 dw sse_sd_instruction-instruction_handler
 db 'cvtsi2sd',2Ah
 dw cvtsi2sd_instruction-instruction_handler
 db 'cvtsi2ss',2Ah
 dw cvtsi2ss_instruction-instruction_handler
 db 'cvtss2sd',5Ah
 dw sse_ss_instruction-instruction_handler
 db 'cvtss2si',2Dh
 dw cvtss2si_instruction-instruction_handler
 db 'fcmovnbe',0D0h
 dw fcomi_instruction-instruction_handler
 db 'fnstenvd',6
 dw fldenv_instruction_32bit-instruction_handler
 db 'fnstenvw',6
 dw fldenv_instruction_16bit-instruction_handler
 db 'fxsave64',0
 dw fxsave_instruction_64bit-instruction_handler
 db 'insertps',21h
 dw insertps_instruction-instruction_handler
 db 'kortestb',98h
 dw mask_instruction_single_source_b-instruction_handler
 db 'kortestd',98h
 dw mask_instruction_single_source_d-instruction_handler
 db 'kortestq',98h
 dw mask_instruction_single_source_q-instruction_handler
 db 'kortestw',98h
 dw mask_instruction_single_source_w-instruction_handler
 db 'kshiftlb',32h
 dw mask_shift_instruction_d-instruction_handler
 db 'kshiftld',33h
 dw mask_shift_instruction_d-instruction_handler
 db 'kshiftlq',33h
 dw mask_shift_instruction_q-instruction_handler
 db 'kshiftlw',32h
 dw mask_shift_instruction_q-instruction_handler
 db 'kshiftrb',30h
 dw mask_shift_instruction_d-instruction_handler
 db 'kshiftrd',31h
 dw mask_shift_instruction_d-instruction_handler
 db 'kshiftrq',31h
 dw mask_shift_instruction_q-instruction_handler
 db 'kshiftrw',30h
 dw mask_shift_instruction_q-instruction_handler
 db 'kunpckbw',4Bh
 dw mask_instruction_b-instruction_handler
 db 'kunpckdq',4Bh
 dw mask_instruction_q-instruction_handler
 db 'kunpckwd',4Bh
 dw mask_instruction_w-instruction_handler
 db 'maskmovq',0
 dw maskmovq_instruction-instruction_handler
 db 'movmskpd',0
 dw movmskpd_instruction-instruction_handler
 db 'movmskps',0
 dw movmskps_instruction-instruction_handler
 db 'movntdqa',2Ah
 dw movntdqa_instruction-instruction_handler
 db 'movshdup',16h
 dw movshdup_instruction-instruction_handler
 db 'movsldup',12h
 dw movshdup_instruction-instruction_handler
 db 'packssdw',6Bh
 dw basic_mmx_instruction-instruction_handler
 db 'packsswb',63h
 dw basic_mmx_instruction-instruction_handler
 db 'packusdw',2Bh
 dw sse4_instruction_66_38-instruction_handler
 db 'packuswb',67h
 dw basic_mmx_instruction-instruction_handler
 db 'pblendvb',10h
 dw sse4_instruction_66_38_xmm0-instruction_handler
 db 'pfrcpit1',0A6h
 dw amd3dnow_instruction-instruction_handler
 db 'pfrcpit2',0B6h
 dw amd3dnow_instruction-instruction_handler
 db 'pfrsqit1',0A7h
 dw amd3dnow_instruction-instruction_handler
 db 'pmovmskb',0D7h
 dw pmovmskb_instruction-instruction_handler
 db 'pmovsxbd',21h
 dw pmovsxbd_instruction-instruction_handler
 db 'pmovsxbq',22h
 dw pmovsxbq_instruction-instruction_handler
 db 'pmovsxbw',20h
 dw pmovsxbw_instruction-instruction_handler
 db 'pmovsxdq',25h
 dw pmovsxdq_instruction-instruction_handler
 db 'pmovsxwd',23h
 dw pmovsxwd_instruction-instruction_handler
 db 'pmovsxwq',24h
 dw pmovsxwq_instruction-instruction_handler
 db 'pmovzxbd',31h
 dw pmovsxbd_instruction-instruction_handler
 db 'pmovzxbq',32h
 dw pmovsxbq_instruction-instruction_handler
 db 'pmovzxbw',30h
 dw pmovsxbw_instruction-instruction_handler
 db 'pmovzxdq',35h
 dw pmovsxdq_instruction-instruction_handler
 db 'pmovzxwd',33h
 dw pmovsxwd_instruction-instruction_handler
 db 'pmovzxwq',34h
 dw pmovsxwq_instruction-instruction_handler
 db 'pmulhrsw',0Bh
 dw ssse3_instruction-instruction_handler
 db 'prefetch',0
 dw amd_prefetch_instruction-instruction_handler
 db 'rdfsbase',0
 dw rdfsbase_instruction-instruction_handler
 db 'rdgsbase',1
 dw rdfsbase_instruction-instruction_handler
 db 'sha1msg1',0C9h
 dw sse4_instruction_38-instruction_handler
 db 'sha1msg2',0CAh
 dw sse4_instruction_38-instruction_handler
 db 'sysenter',34h
 dw simple_extended_instruction-instruction_handler
 db 'sysexitq',35h
 dw simple_extended_instruction_64bit-instruction_handler
 db 'unpckhpd',15h
 dw sse_pd_instruction-instruction_handler
 db 'unpckhps',15h
 dw sse_ps_instruction-instruction_handler
 db 'unpcklpd',14h
 dw sse_pd_instruction-instruction_handler
 db 'unpcklps',14h
 dw sse_ps_instruction-instruction_handler
 db 'vblendpd',0Dh
 dw avx_pi_instruction_3a_imm8_noevex-instruction_handler
 db 'vblendps',0Ch
 dw avx_pi_instruction_3a_imm8_noevex-instruction_handler
 db 'vcmpeqpd',0
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpeqps',0
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpeqsd',0
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpeqss',0
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpgepd',0Dh
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpgeps',0Dh
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpgesd',0Dh
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpgess',0Dh
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpgtpd',0Eh
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpgtps',0Eh
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpgtsd',0Eh
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpgtss',0Eh
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmplepd',2
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpleps',2
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmplesd',2
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpless',2
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpltpd',1
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpltps',1
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpltsd',1
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpltss',1
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vfmaddpd',69h
 dw fma4_instruction_p-instruction_handler
 db 'vfmaddps',68h
 dw fma4_instruction_p-instruction_handler
 db 'vfmaddsd',6Bh
 dw fma4_instruction_sd-instruction_handler
 db 'vfmaddss',6Ah
 dw fma4_instruction_ss-instruction_handler
 db 'vfmsubpd',6Dh
 dw fma4_instruction_p-instruction_handler
 db 'vfmsubps',6Ch
 dw fma4_instruction_p-instruction_handler
 db 'vfmsubsd',6Fh
 dw fma4_instruction_sd-instruction_handler
 db 'vfmsubss',6Eh
 dw fma4_instruction_ss-instruction_handler
 db 'vldmxcsr',10b
 dw vldmxcsr_instruction-instruction_handler
 db 'vmlaunch',0C2h
 dw simple_vmx_instruction-instruction_handler
 db 'vmovddup',12h
 dw avx_movddup_instruction-instruction_handler
 db 'vmovdqu8',6Fh
 dw avx512_movdqu8_instruction-instruction_handler
 db 'vmovhlps',12h
 dw avx_movhlps_instruction-instruction_handler
 db 'vmovlhps',16h
 dw avx_movhlps_instruction-instruction_handler
 db 'vmovntdq',0E7h
 dw avx_movntdq_instruction-instruction_handler
 db 'vmovntpd',2Bh
 dw avx_movntpd_instruction-instruction_handler
 db 'vmovntps',2Bh
 dw avx_movntps_instruction-instruction_handler
 db 'vmpsadbw',42h
 dw avx_pi_instruction_3a_imm8_noevex-instruction_handler
 db 'vmresume',0C3h
 dw simple_vmx_instruction-instruction_handler
 db 'vpaddusb',0DCh
 dw avx_bw_instruction-instruction_handler
 db 'vpaddusw',0DDh
 dw avx_bw_instruction-instruction_handler
 db 'vpalignr',0Fh
 dw avx_pi_instruction_3a_imm8-instruction_handler
 db 'vpblendd',2
 dw avx_pi_instruction_3a_imm8_noevex-instruction_handler
 db 'vpblendw',0Eh
 dw avx_pi_instruction_3a_imm8_noevex-instruction_handler
 db 'vpcmpeqb',74h
 dw avx_cmpeqb_instruction-instruction_handler
 db 'vpcmpeqd',76h
 dw avx_cmpeqd_instruction-instruction_handler
 db 'vpcmpeqq',29h
 dw avx_cmpeqq_instruction-instruction_handler
 db 'vpcmpeqw',75h
 dw avx_cmpeqb_instruction-instruction_handler
 db 'vpcmpgtb',64h
 dw avx_cmpeqb_instruction-instruction_handler
 db 'vpcmpgtd',66h
 dw avx_cmpeqd_instruction-instruction_handler
 db 'vpcmpgtq',37h
 dw avx_cmpeqq_instruction-instruction_handler
 db 'vpcmpgtw',65h
 dw avx_cmpeqb_instruction-instruction_handler
 db 'vpcmpleb',2
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcmpled',2
 dw avx512_cmp_d_instruction-instruction_handler
 db 'vpcmpleq',2
 dw avx512_cmp_q_instruction-instruction_handler
 db 'vpcmplew',2
 dw avx512_cmp_w_instruction-instruction_handler
 db 'vpcmpltb',1
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcmpltd',1
 dw avx512_cmp_d_instruction-instruction_handler
 db 'vpcmpltq',1
 dw avx512_cmp_q_instruction-instruction_handler
 db 'vpcmpltw',1
 dw avx512_cmp_w_instruction-instruction_handler
 db 'vpcomeqb',4
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomeqd',4
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomeqq',4
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomeqw',4
 dw xop_pcom_w_instruction-instruction_handler
 db 'vpcomgeb',3
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomged',3
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomgeq',3
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomgew',3
 dw xop_pcom_w_instruction-instruction_handler
 db 'vpcomgtb',2
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomgtd',2
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomgtq',2
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomgtw',2
 dw xop_pcom_w_instruction-instruction_handler
 db 'vpcomleb',1
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomled',1
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomleq',1
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomlew',1
 dw xop_pcom_w_instruction-instruction_handler
 db 'vpcomltb',0
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomltd',0
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomltq',0
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomltw',0
 dw xop_pcom_w_instruction-instruction_handler
 db 'vpermi2b',75h
 dw avx_bw_instruction_38_evex-instruction_handler
 db 'vpermi2d',76h
 dw avx_d_instruction_38_evex-instruction_handler
 db 'vpermi2q',76h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpermi2w',75h
 dw avx_bw_instruction_38_w1_evex-instruction_handler
 db 'vpermt2b',7Dh
 dw avx_bw_instruction_38_evex-instruction_handler
 db 'vpermt2d',7Eh
 dw avx_d_instruction_38_evex-instruction_handler
 db 'vpermt2q',7Eh
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpermt2w',7Dh
 dw avx_bw_instruction_38_w1_evex-instruction_handler
 db 'vphaddbd',0C2h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphaddbq',0C3h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphaddbw',0C1h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphadddq',0CBh
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphaddsw',3
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vphaddwd',0C6h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphaddwq',0C7h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphsubbw',0E1h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphsubdq',0E3h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphsubsw',7
 dw avx_pi_instruction_38_noevex-instruction_handler
 db 'vphsubwd',0E2h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vplzcntd',44h
 dw avx_single_source_d_instruction_38_evex-instruction_handler
 db 'vplzcntq',44h
 dw avx_single_source_q_instruction_38_evex-instruction_handler
 db 'vpmacsdd',9Eh
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmacswd',96h
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmacsww',95h
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmaddwd',0F5h
 dw avx_bw_instruction-instruction_handler
 db 'vpmovb2m',29h
 dw avx512_pmov_2m_instruction-instruction_handler
 db 'vpmovd2m',39h
 dw avx512_pmov_2m_instruction-instruction_handler
 db 'vpmovm2b',28h
 dw avx512_pmov_m2_instruction-instruction_handler
 db 'vpmovm2d',38h
 dw avx512_pmov_m2_instruction-instruction_handler
 db 'vpmovm2q',38h
 dw avx512_pmov_m2_instruction_w1-instruction_handler
 db 'vpmovm2w',28h
 dw avx512_pmov_m2_instruction_w1-instruction_handler
 db 'vpmovq2m',39h
 dw avx512_pmov_2m_instruction_w1-instruction_handler
 db 'vpmovsdb',21h
 dw avx512_pmovdb_instruction-instruction_handler
 db 'vpmovsdw',23h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmovsqb',22h
 dw avx512_pmovqb_instruction-instruction_handler
 db 'vpmovsqd',25h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmovsqw',24h
 dw avx512_pmovdb_instruction-instruction_handler
 db 'vpmovswb',20h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmovw2m',29h
 dw avx512_pmov_2m_instruction_w1-instruction_handler
 db 'vpmulhuw',0E4h
 dw avx_bw_instruction-instruction_handler
 db 'vpmuludq',0F4h
 dw avx_q_instruction-instruction_handler
 db 'vpshufhw',0F3h
 dw avx_pshuf_w_instruction-instruction_handler
 db 'vpshuflw',0F2h
 dw avx_pshuf_w_instruction-instruction_handler
 db 'vpsubusb',0D8h
 dw avx_bw_instruction-instruction_handler
 db 'vpsubusw',0D9h
 dw avx_bw_instruction-instruction_handler
 db 'vptestmb',26h
 dw avx512_ptestmb_instruction-instruction_handler
 db 'vptestmd',27h
 dw avx512_ptestmd_instruction-instruction_handler
 db 'vptestmq',27h
 dw avx512_ptestmq_instruction-instruction_handler
 db 'vptestmw',26h
 dw avx512_ptestmw_instruction-instruction_handler
 db 'vrangepd',50h
 dw avx512_pd_instruction_sae_imm8-instruction_handler
 db 'vrangeps',50h
 dw avx512_ps_instruction_sae_imm8-instruction_handler
 db 'vrangesd',51h
 dw avx512_sd_instruction_sae_imm8-instruction_handler
 db 'vrangess',51h
 dw avx512_ss_instruction_sae_imm8-instruction_handler
 db 'vrcp14pd',4Ch
 dw avx512_single_source_pd_instruction-instruction_handler
 db 'vrcp14ps',4Ch
 dw avx512_single_source_ps_instruction-instruction_handler
 db 'vrcp14sd',4Dh
 dw avx512_sd_instruction-instruction_handler
 db 'vrcp14ss',4Dh
 dw avx512_ss_instruction-instruction_handler
 db 'vrcp28pd',0CAh
 dw avx512_exp2pd_instruction-instruction_handler
 db 'vrcp28ps',0CAh
 dw avx512_exp2ps_instruction-instruction_handler
 db 'vrcp28sd',0CBh
 dw avx512_sd_instruction_sae-instruction_handler
 db 'vrcp28ss',0CBh
 dw avx512_ss_instruction_sae-instruction_handler
 db 'vroundpd',9
 dw avx_single_source_instruction_3a_imm8_noevex-instruction_handler
 db 'vroundps',8
 dw avx_single_source_instruction_3a_imm8_noevex-instruction_handler
 db 'vroundsd',0Bh
 dw avx_sd_instruction_3a_imm8_noevex-instruction_handler
 db 'vroundss',0Ah
 dw avx_ss_instruction_3a_imm8_noevex-instruction_handler
 db 'vrsqrtps',52h
 dw avx_single_source_ps_instruction_noevex-instruction_handler
 db 'vrsqrtss',52h
 dw avx_ss_instruction_noevex-instruction_handler
 db 'vstmxcsr',11b
 dw vldmxcsr_instruction-instruction_handler
 db 'vucomisd',2Eh
 dw avx_comisd_instruction-instruction_handler
 db 'vucomiss',2Eh
 dw avx_comiss_instruction-instruction_handler
 db 'vzeroall',77h
 dw vzeroall_instruction-instruction_handler
 db 'wrfsbase',2
 dw rdfsbase_instruction-instruction_handler
 db 'wrgsbase',3
 dw rdfsbase_instruction-instruction_handler
 db 'xacquire',0F2h
 dw prefix_instruction-instruction_handler
 db 'xrelease',0F3h
 dw prefix_instruction-instruction_handler
 db 'xrstor64',101b
 dw fxsave_instruction_64bit-instruction_handler
 db 'xsaveopt',110b
 dw fxsave_instruction-instruction_handler
instructions_9:
 db 'cmpxchg8b',8
 dw cmpxchgx_instruction-instruction_handler
 db 'cvttpd2dq',0E6h
 dw sse_pd_instruction-instruction_handler
 db 'cvttpd2pi',2Ch
 dw cvtpd2pi_instruction-instruction_handler
 db 'cvttps2dq',5Bh
 dw movshdup_instruction-instruction_handler
 db 'cvttps2pi',2Ch
 dw cvtps2pi_instruction-instruction_handler
 db 'cvttsd2si',2Ch
 dw cvtsd2si_instruction-instruction_handler
 db 'cvttss2si',2Ch
 dw cvtss2si_instruction-instruction_handler
 db 'extractps',17h
 dw extractps_instruction-instruction_handler
 db 'fxrstor64',1
 dw fxsave_instruction_64bit-instruction_handler
 db 'pclmulqdq',-1
 dw pclmulqdq_instruction-instruction_handler
 db 'pcmpestri',61h
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'pcmpestrm',60h
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'pcmpistri',63h
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'pcmpistrm',62h
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'pmaddubsw',4
 dw ssse3_instruction-instruction_handler
 db 'prefetchw',1
 dw amd_prefetch_instruction-instruction_handler
 db 'punpckhbw',68h
 dw basic_mmx_instruction-instruction_handler
 db 'punpckhdq',6Ah
 dw basic_mmx_instruction-instruction_handler
 db 'punpckhwd',69h
 dw basic_mmx_instruction-instruction_handler
 db 'punpcklbw',60h
 dw basic_mmx_instruction-instruction_handler
 db 'punpckldq',62h
 dw basic_mmx_instruction-instruction_handler
 db 'punpcklwd',61h
 dw basic_mmx_instruction-instruction_handler
 db 'sha1nexte',0C8h
 dw sse4_instruction_38-instruction_handler
 db 'sha1rnds4',0CCh
 dw sse4_instruction_3a_imm8-instruction_handler
 db 'useavx256',0
 dw set_evex_mode-instruction_handler
 db 'useavx512',1
 dw set_evex_mode-instruction_handler
 db 'vaddsubpd',0D0h
 dw avx_pd_instruction_noevex-instruction_handler
 db 'vaddsubps',0D0h
 dw avx_ps_instruction_noevex-instruction_handler
 db 'vblendmpd',65h
 dw avx_pd_instruction_38_evex-instruction_handler
 db 'vblendmps',65h
 dw avx_ps_instruction_66_38_evex-instruction_handler
 db 'vblendvpd',4Bh
 dw avx_triple_source_instruction_3a_noevex-instruction_handler
 db 'vblendvps',4Ah
 dw avx_triple_source_instruction_3a_noevex-instruction_handler
 db 'vcmpneqpd',4
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpneqps',4
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpneqsd',4
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpneqss',4
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpngepd',9
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpngeps',9
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpngesd',9
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpngess',9
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpngtpd',0Ah
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpngtps',0Ah
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpngtsd',0Ah
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpngtss',0Ah
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpnlepd',6
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpnleps',6
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpnlesd',6
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpnless',6
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpnltpd',5
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpnltps',5
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpnltsd',5
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpnltss',5
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpordpd',7
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpordps',7
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpordsd',7
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpordss',7
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcvtdq2pd',0E6h
 dw avx_cvtdq2pd_instruction-instruction_handler
 db 'vcvtdq2ps',5Bh
 dw avx_single_source_ps_instruction_er-instruction_handler
 db 'vcvtpd2dq',0E6h
 dw avx_cvtpd2dq_instruction-instruction_handler
 db 'vcvtpd2ps',5Ah
 dw avx_cvtpd2ps_instruction-instruction_handler
 db 'vcvtpd2qq',7Bh
 dw avx_single_source_pd_instruction_er_evex-instruction_handler
 db 'vcvtph2ps',13h
 dw avx_cvtph2ps_instruction-instruction_handler
 db 'vcvtps2dq',5Bh
 dw avx_cvtps2dq_instruction-instruction_handler
 db 'vcvtps2pd',5Ah
 dw avx_cvtps2pd_instruction-instruction_handler
 db 'vcvtps2ph',1Dh
 dw avx_cvtps2ph_instruction-instruction_handler
 db 'vcvtps2qq',7Bh
 dw avx_cvtps2qq_instruction-instruction_handler
 db 'vcvtqq2pd',0E6h
 dw avx_cvtqq2pd_instruction-instruction_handler
 db 'vcvtqq2ps',5Bh
 dw avx_cvtpd2udq_instruction-instruction_handler
 db 'vcvtsd2si',2Dh
 dw avx_cvtsd2si_instruction-instruction_handler
 db 'vcvtsd2ss',5Ah
 dw avx_sd_instruction_er-instruction_handler
 db 'vcvtsi2sd',2Ah
 dw avx_cvtsi2sd_instruction-instruction_handler
 db 'vcvtsi2ss',2Ah
 dw avx_cvtsi2ss_instruction-instruction_handler
 db 'vcvtss2sd',5Ah
 dw avx_ss_instruction_sae-instruction_handler
 db 'vcvtss2si',2Dh
 dw avx_cvtss2si_instruction-instruction_handler
 db 'vdbpsadbw',42h
 dw avx_d_instruction_3a_imm8_evex-instruction_handler
 db 'vexpandpd',88h
 dw avx_single_source_q_instruction_38_evex-instruction_handler
 db 'vexpandps',88h
 dw avx_single_source_d_instruction_38_evex-instruction_handler
 db 'vfnmaddpd',79h
 dw fma4_instruction_p-instruction_handler
 db 'vfnmaddps',78h
 dw fma4_instruction_p-instruction_handler
 db 'vfnmaddsd',7Bh
 dw fma4_instruction_sd-instruction_handler
 db 'vfnmaddss',7Ah
 dw fma4_instruction_ss-instruction_handler
 db 'vfnmsubpd',7Dh
 dw fma4_instruction_p-instruction_handler
 db 'vfnmsubps',7Ch
 dw fma4_instruction_p-instruction_handler
 db 'vfnmsubsd',7Fh
 dw fma4_instruction_sd-instruction_handler
 db 'vfnmsubss',7Eh
 dw fma4_instruction_ss-instruction_handler
 db 'vgetexppd',42h
 dw avx512_single_source_pd_instruction_sae-instruction_handler
 db 'vgetexpps',42h
 dw avx512_single_source_ps_instruction_sae-instruction_handler
 db 'vgetexpsd',43h
 dw avx512_sd_instruction_sae-instruction_handler
 db 'vgetexpss',43h
 dw avx512_ss_instruction_sae-instruction_handler
 db 'vinsertps',21h
 dw avx_insertps_instruction-instruction_handler
 db 'vmovdqa32',6Fh
 dw avx512_movdqa32_instruction-instruction_handler
 db 'vmovdqa64',6Fh
 dw avx512_movdqa64_instruction-instruction_handler
 db 'vmovdqu16',6Fh
 dw avx512_movdqu16_instruction-instruction_handler
 db 'vmovdqu32',6Fh
 dw avx512_movdqu32_instruction-instruction_handler
 db 'vmovdqu64',6Fh
 dw avx512_movdqu64_instruction-instruction_handler
 db 'vmovmskpd',0
 dw avx_movmskpd_instruction-instruction_handler
 db 'vmovmskps',0
 dw avx_movmskps_instruction-instruction_handler
 db 'vmovntdqa',2Ah
 dw avx_movntdqa_instruction-instruction_handler
 db 'vmovshdup',16h
 dw avx_movshdup_instruction-instruction_handler
 db 'vmovsldup',12h
 dw avx_movshdup_instruction-instruction_handler
 db 'vpackssdw',6Bh
 dw avx_d_instruction-instruction_handler
 db 'vpacksswb',63h
 dw avx_bw_instruction-instruction_handler
 db 'vpackusdw',2Bh
 dw avx_d_instruction_38-instruction_handler
 db 'vpackuswb',67h
 dw avx_bw_instruction-instruction_handler
 db 'vpblendmb',66h
 dw avx_bw_instruction_38_evex-instruction_handler
 db 'vpblendmd',64h
 dw avx_d_instruction_38_evex-instruction_handler
 db 'vpblendmq',64h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpblendmw',66h
 dw avx_bw_instruction_38_w1_evex-instruction_handler
 db 'vpblendvb',4Ch
 dw avx_triple_source_instruction_3a_noevex-instruction_handler
 db 'vpcmpleub',2
 dw avx512_cmp_ub_instruction-instruction_handler
 db 'vpcmpleud',2
 dw avx512_cmp_ud_instruction-instruction_handler
 db 'vpcmpleuq',2
 dw avx512_cmp_uq_instruction-instruction_handler
 db 'vpcmpleuw',2
 dw avx512_cmp_uw_instruction-instruction_handler
 db 'vpcmpltub',1
 dw avx512_cmp_ub_instruction-instruction_handler
 db 'vpcmpltud',1
 dw avx512_cmp_ud_instruction-instruction_handler
 db 'vpcmpltuq',1
 dw avx512_cmp_uq_instruction-instruction_handler
 db 'vpcmpltuw',1
 dw avx512_cmp_uw_instruction-instruction_handler
 db 'vpcmpneqb',4
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcmpneqd',4
 dw avx512_cmp_d_instruction-instruction_handler
 db 'vpcmpneqq',4
 dw avx512_cmp_q_instruction-instruction_handler
 db 'vpcmpneqw',4
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcmpnleb',6
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcmpnled',6
 dw avx512_cmp_d_instruction-instruction_handler
 db 'vpcmpnleq',6
 dw avx512_cmp_q_instruction-instruction_handler
 db 'vpcmpnlew',6
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcmpnltb',5
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcmpnltd',5
 dw avx512_cmp_d_instruction-instruction_handler
 db 'vpcmpnltq',5
 dw avx512_cmp_q_instruction-instruction_handler
 db 'vpcmpnltw',5
 dw avx512_cmp_b_instruction-instruction_handler
 db 'vpcomequb',4
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomequd',4
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomequq',4
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomequw',4
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpcomgeub',3
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomgeud',3
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomgeuq',3
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomgeuw',3
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpcomgtub',2
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomgtud',2
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomgtuq',2
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomgtuw',2
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpcomleub',1
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomleud',1
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomleuq',1
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomleuw',1
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpcomltub',0
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomltud',0
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomltuq',0
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomltuw',0
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpcomneqb',5
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomneqd',5
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomneqq',5
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomneqw',5
 dw xop_pcom_w_instruction-instruction_handler
 db 'vpermi2pd',77h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpermi2ps',77h
 dw avx_d_instruction_38_evex-instruction_handler
 db 'vpermilpd',5
 dw avx_permilpd_instruction-instruction_handler
 db 'vpermilps',4
 dw avx_permilps_instruction-instruction_handler
 db 'vpermt2pd',7Fh
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpermt2ps',7Fh
 dw avx_d_instruction_38_evex-instruction_handler
 db 'vpexpandd',89h
 dw avx_single_source_d_instruction_38_evex-instruction_handler
 db 'vpexpandq',89h
 dw avx_single_source_q_instruction_38_evex-instruction_handler
 db 'vphaddubd',0D2h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphaddubq',0D3h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphaddubw',0D1h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphaddudq',0DBh
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphadduwd',0D6h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vphadduwq',0D7h
 dw xop_single_source_128bit_instruction-instruction_handler
 db 'vpmacsdqh',9Fh
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmacsdql',97h
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmacssdd',8Eh
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmacsswd',86h
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmacssww',85h
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmadcswd',0B6h
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmovmskb',0D7h
 dw avx_pmovmskb_instruction-instruction_handler
 db 'vpmovsxbd',21h
 dw avx_pmovsxbd_instruction-instruction_handler
 db 'vpmovsxbq',22h
 dw avx_pmovsxbq_instruction-instruction_handler
 db 'vpmovsxbw',20h
 dw avx_pmovsxbw_instruction-instruction_handler
 db 'vpmovsxdq',25h
 dw avx_pmovsxbw_instruction-instruction_handler
 db 'vpmovsxwd',23h
 dw avx_pmovsxbw_instruction-instruction_handler
 db 'vpmovsxwq',24h
 dw avx_pmovsxbd_instruction-instruction_handler
 db 'vpmovusdb',11h
 dw avx512_pmovdb_instruction-instruction_handler
 db 'vpmovusdw',13h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmovusqb',12h
 dw avx512_pmovqb_instruction-instruction_handler
 db 'vpmovusqd',15h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmovusqw',14h
 dw avx512_pmovdb_instruction-instruction_handler
 db 'vpmovuswb',10h
 dw avx512_pmovwb_instruction-instruction_handler
 db 'vpmovzxbd',31h
 dw avx_pmovsxbd_instruction-instruction_handler
 db 'vpmovzxbq',32h
 dw avx_pmovsxbq_instruction-instruction_handler
 db 'vpmovzxbw',30h
 dw avx_pmovsxbw_instruction-instruction_handler
 db 'vpmovzxdq',35h
 dw avx_pmovsxbw_instruction-instruction_handler
 db 'vpmovzxwd',33h
 dw avx_pmovsxbw_instruction-instruction_handler
 db 'vpmovzxwq',34h
 dw avx_pmovsxbd_instruction-instruction_handler
 db 'vpmulhrsw',0Bh
 dw avx_bw_instruction_38-instruction_handler
 db 'vptestnmb',26h
 dw avx512_ptestnmb_instruction-instruction_handler
 db 'vptestnmd',27h
 dw avx512_ptestnmd_instruction-instruction_handler
 db 'vptestnmq',27h
 dw avx512_ptestnmq_instruction-instruction_handler
 db 'vptestnmw',26h
 dw avx512_ptestnmw_instruction-instruction_handler
 db 'vreducepd',56h
 dw avx512_single_source_pd_instruction_sae_imm8-instruction_handler
 db 'vreduceps',56h
 dw avx512_single_source_ps_instruction_sae_imm8-instruction_handler
 db 'vreducesd',57h
 dw avx512_sd_instruction_sae_imm8-instruction_handler
 db 'vreducess',57h
 dw avx512_ss_instruction_sae_imm8-instruction_handler
 db 'vscalefpd',2Ch
 dw avx512_pd_instruction_er-instruction_handler
 db 'vscalefps',2Ch
 dw avx512_ps_instruction_er-instruction_handler
 db 'vscalefsd',2Dh
 dw avx512_sd_instruction_er-instruction_handler
 db 'vscalefss',2Dh
 dw avx512_ss_instruction_er-instruction_handler
 db 'vunpckhpd',15h
 dw avx_pd_instruction-instruction_handler
 db 'vunpckhps',15h
 dw avx_ps_instruction-instruction_handler
 db 'vunpcklpd',14h
 dw avx_pd_instruction-instruction_handler
 db 'vunpcklps',14h
 dw avx_ps_instruction-instruction_handler
instructions_10:
 db 'aesdeclast',0DFh
 dw sse4_instruction_66_38-instruction_handler
 db 'aesenclast',0DDh
 dw sse4_instruction_66_38-instruction_handler
 db 'clflushopt',7
 dw clflushopt_instruction-instruction_handler
 db 'cmpunordpd',3
 dw cmp_pd_instruction-instruction_handler
 db 'cmpunordps',3
 dw cmp_ps_instruction-instruction_handler
 db 'cmpunordsd',3
 dw cmp_sd_instruction-instruction_handler
 db 'cmpunordss',3
 dw cmp_ss_instruction-instruction_handler
 db 'cmpxchg16b',16
 dw cmpxchgx_instruction-instruction_handler
 db 'loadall286',5
 dw simple_extended_instruction-instruction_handler
 db 'loadall386',7
 dw simple_extended_instruction-instruction_handler
 db 'maskmovdqu',0
 dw maskmovdqu_instruction-instruction_handler
 db 'phminposuw',41h
 dw sse4_instruction_66_38-instruction_handler
 db 'prefetcht0',1
 dw prefetch_instruction-instruction_handler
 db 'prefetcht1',2
 dw prefetch_instruction-instruction_handler
 db 'prefetcht2',3
 dw prefetch_instruction-instruction_handler
 db 'punpckhqdq',6Dh
 dw sse_pd_instruction-instruction_handler
 db 'punpcklqdq',6Ch
 dw sse_pd_instruction-instruction_handler
 db 'sha256msg1',0CCh
 dw sse4_instruction_38-instruction_handler
 db 'sha256msg2',0CDh
 dw sse4_instruction_38-instruction_handler
 db 'vcmptruepd',0Fh
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmptrueps',0Fh
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmptruesd',0Fh
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmptruess',0Fh
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcvtpd2udq',79h
 dw avx_cvtpd2udq_instruction-instruction_handler
 db 'vcvtpd2uqq',79h
 dw avx_single_source_pd_instruction_er_evex-instruction_handler
 db 'vcvtps2udq',79h
 dw avx_single_source_ps_instruction_er_evex-instruction_handler
 db 'vcvtps2uqq',79h
 dw avx_cvtps2qq_instruction-instruction_handler
 db 'vcvtsd2usi',79h
 dw avx_cvtsd2usi_instruction-instruction_handler
 db 'vcvtss2usi',79h
 dw avx_cvtss2usi_instruction-instruction_handler
 db 'vcvttpd2dq',0E6h
 dw avx_cvttpd2dq_instruction-instruction_handler
 db 'vcvttpd2qq',7Ah
 dw avx_single_source_pd_instruction_sae_evex-instruction_handler
 db 'vcvttps2dq',5Bh
 dw avx_cvttps2dq_instruction-instruction_handler
 db 'vcvttps2qq',7Ah
 dw avx_cvttps2qq_instruction-instruction_handler
 db 'vcvttsd2si',2Ch
 dw avx_cvttsd2si_instruction-instruction_handler
 db 'vcvttss2si',2Ch
 dw avx_cvttss2si_instruction-instruction_handler
 db 'vcvtudq2pd',7Ah
 dw avx_cvtudq2pd_instruction-instruction_handler
 db 'vcvtudq2ps',7Ah
 dw avx_cvtudq2ps_instruction-instruction_handler
 db 'vcvtuqq2pd',7Ah
 dw avx_cvtqq2pd_instruction-instruction_handler
 db 'vcvtuqq2ps',7Ah
 dw avx_cvtuqq2ps_instruction-instruction_handler
 db 'vcvtusi2sd',7Bh
 dw avx_cvtusi2sd_instruction-instruction_handler
 db 'vcvtusi2ss',7Bh
 dw avx_cvtusi2ss_instruction-instruction_handler
 db 'vextractps',17h
 dw avx_extract_d_instruction-instruction_handler
 db 'vfpclasspd',66h
 dw avx512_fpclasspd_instruction-instruction_handler
 db 'vfpclassps',66h
 dw avx512_fpclassps_instruction-instruction_handler
 db 'vfpclasssd',67h
 dw avx512_fpclasssd_instruction-instruction_handler
 db 'vfpclassss',67h
 dw avx512_fpclassss_instruction-instruction_handler
 db 'vgatherdpd',92h
 dw gather_pd_instruction-instruction_handler
 db 'vgatherdps',92h
 dw gather_ps_instruction-instruction_handler
 db 'vgatherqpd',93h
 dw gather_pd_instruction-instruction_handler
 db 'vgatherqps',93h
 dw gather_ps_instruction-instruction_handler
 db 'vgetmantpd',26h
 dw avx512_single_source_pd_instruction_sae_imm8-instruction_handler
 db 'vgetmantps',26h
 dw avx512_single_source_ps_instruction_sae_imm8-instruction_handler
 db 'vgetmantsd',27h
 dw avx512_sd_instruction_sae_imm8-instruction_handler
 db 'vgetmantss',27h
 dw avx512_ss_instruction_sae_imm8-instruction_handler
 db 'vmaskmovpd',2Dh
 dw avx_maskmov_instruction-instruction_handler
 db 'vmaskmovps',2Ch
 dw avx_maskmov_instruction-instruction_handler
 db 'vpclmulqdq',-1
 dw avx_pclmulqdq_instruction-instruction_handler
 db 'vpcmpestri',61h
 dw avx_single_source_128bit_instruction_3a_imm8_noevex-instruction_handler
 db 'vpcmpestrm',60h
 dw avx_single_source_128bit_instruction_3a_imm8_noevex-instruction_handler
 db 'vpcmpistri',63h
 dw avx_single_source_128bit_instruction_3a_imm8_noevex-instruction_handler
 db 'vpcmpistrm',62h
 dw avx_single_source_128bit_instruction_3a_imm8_noevex-instruction_handler
 db 'vpcmpnequb',4
 dw avx512_cmp_ub_instruction-instruction_handler
 db 'vpcmpnequd',4
 dw avx512_cmp_ud_instruction-instruction_handler
 db 'vpcmpnequq',4
 dw avx512_cmp_uq_instruction-instruction_handler
 db 'vpcmpnequw',4
 dw avx512_cmp_uw_instruction-instruction_handler
 db 'vpcmpnleub',6
 dw avx512_cmp_ub_instruction-instruction_handler
 db 'vpcmpnleud',6
 dw avx512_cmp_ud_instruction-instruction_handler
 db 'vpcmpnleuq',6
 dw avx512_cmp_uq_instruction-instruction_handler
 db 'vpcmpnleuw',6
 dw avx512_cmp_uw_instruction-instruction_handler
 db 'vpcmpnltub',5
 dw avx512_cmp_ub_instruction-instruction_handler
 db 'vpcmpnltud',5
 dw avx512_cmp_ud_instruction-instruction_handler
 db 'vpcmpnltuq',5
 dw avx512_cmp_uq_instruction-instruction_handler
 db 'vpcmpnltuw',5
 dw avx512_cmp_uw_instruction-instruction_handler
 db 'vpcomnequb',5
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomnequd',5
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomnequq',5
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomnequw',5
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpcomtrueb',7
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomtrued',7
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomtrueq',7
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomtruew',7
 dw xop_pcom_w_instruction-instruction_handler
 db 'vperm2f128',6
 dw avx_perm2f128_instruction-instruction_handler
 db 'vperm2i128',46h
 dw avx_perm2f128_instruction-instruction_handler
 db 'vpermil2pd',49h
 dw vpermil2_instruction-instruction_handler
 db 'vpermil2ps',48h
 dw vpermil2_instruction-instruction_handler
 db 'vpgatherdd',90h
 dw gather_ps_instruction-instruction_handler
 db 'vpgatherdq',90h
 dw gather_pd_instruction-instruction_handler
 db 'vpgatherqd',91h
 dw gather_ps_instruction-instruction_handler
 db 'vpgatherqq',91h
 dw gather_pd_instruction-instruction_handler
 db 'vpmacssdqh',8Fh
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmacssdql',87h
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmadcsswd',0A6h
 dw xop_triple_source_128bit_instruction-instruction_handler
 db 'vpmaddubsw',4
 dw avx_bw_instruction_38-instruction_handler
 db 'vpmaskmovd',8Ch
 dw avx_maskmov_instruction-instruction_handler
 db 'vpmaskmovq',8Ch
 dw avx_maskmov_w1_instruction-instruction_handler
 db 'vpternlogd',25h
 dw avx_d_instruction_3a_imm8_evex-instruction_handler
 db 'vpternlogq',25h
 dw avx_q_instruction_3a_imm8_evex-instruction_handler
 db 'vpunpckhbw',68h
 dw avx_bw_instruction-instruction_handler
 db 'vpunpckhdq',6Ah
 dw avx_d_instruction-instruction_handler
 db 'vpunpckhwd',69h
 dw avx_bw_instruction-instruction_handler
 db 'vpunpcklbw',60h
 dw avx_bw_instruction-instruction_handler
 db 'vpunpckldq',62h
 dw avx_d_instruction-instruction_handler
 db 'vpunpcklwd',61h
 dw avx_bw_instruction-instruction_handler
 db 'vrsqrt14pd',4Eh
 dw avx512_single_source_pd_instruction-instruction_handler
 db 'vrsqrt14ps',4Eh
 dw avx512_single_source_ps_instruction-instruction_handler
 db 'vrsqrt14sd',4Fh
 dw avx512_sd_instruction-instruction_handler
 db 'vrsqrt14ss',4Fh
 dw avx512_ss_instruction-instruction_handler
 db 'vrsqrt28pd',0CCh
 dw avx512_exp2pd_instruction-instruction_handler
 db 'vrsqrt28ps',0CCh
 dw avx512_exp2ps_instruction-instruction_handler
 db 'vrsqrt28sd',0CDh
 dw avx512_sd_instruction_sae-instruction_handler
 db 'vrsqrt28ss',0CDh
 dw avx512_ss_instruction_sae-instruction_handler
 db 'vshuff32x4',23h
 dw avx512_shuf_d_instruction-instruction_handler
 db 'vshuff64x2',23h
 dw avx512_shuf_q_instruction-instruction_handler
 db 'vshufi32x4',43h
 dw avx512_shuf_d_instruction-instruction_handler
 db 'vshufi64x2',43h
 dw avx512_shuf_q_instruction-instruction_handler
 db 'vzeroupper',77h
 dw vzeroupper_instruction-instruction_handler
 db 'xsaveopt64',110b
 dw fxsave_instruction_64bit-instruction_handler
instructions_11:
 db 'pclmulhqhdq',10001b
 dw pclmulqdq_instruction-instruction_handler
 db 'pclmullqhdq',10000b
 dw pclmulqdq_instruction-instruction_handler
 db 'prefetchnta',0
 dw prefetch_instruction-instruction_handler
 db 'prefetchwt1',2
 dw amd_prefetch_instruction-instruction_handler
 db 'sha256rnds2',0CBh
 dw sse4_instruction_38_xmm0-instruction_handler
 db 'vaesdeclast',0DFh
 dw avx_128bit_instruction_38_noevex-instruction_handler
 db 'vaesenclast',0DDh
 dw avx_128bit_instruction_38_noevex-instruction_handler
 db 'vcmpeq_ospd',10h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpeq_osps',10h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpeq_ossd',10h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpeq_osss',10h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpeq_uqpd',8
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpeq_uqps',8
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpeq_uqsd',8
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpeq_uqss',8
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpeq_uspd',18h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpeq_usps',18h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpeq_ussd',18h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpeq_usss',18h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpfalsepd',0Bh
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpfalseps',0Bh
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpfalsesd',0Bh
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpfalsess',0Bh
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpge_oqpd',1Dh
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpge_oqps',1Dh
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpge_oqsd',1Dh
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpge_oqss',1Dh
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpgt_oqpd',1Eh
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpgt_oqps',1Eh
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpgt_oqsd',1Eh
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpgt_oqss',1Eh
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmple_oqpd',12h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmple_oqps',12h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmple_oqsd',12h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmple_oqss',12h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmplt_oqpd',11h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmplt_oqps',11h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmplt_oqsd',11h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmplt_oqss',11h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpord_spd',17h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpord_sps',17h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpord_ssd',17h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpord_sss',17h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpunordpd',3
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpunordps',3
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpunordsd',3
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpunordss',3
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcompresspd',8Ah
 dw avx_compress_q_instruction-instruction_handler
 db 'vcompressps',8Ah
 dw avx_compress_d_instruction-instruction_handler
 db 'vcvttpd2udq',78h
 dw avx_cvttpd2udq_instruction-instruction_handler
 db 'vcvttpd2uqq',78h
 dw avx_single_source_pd_instruction_sae_evex-instruction_handler
 db 'vcvttps2udq',78h
 dw avx_cvttps2udq_instruction-instruction_handler
 db 'vcvttps2uqq',78h
 dw avx_cvttps2qq_instruction-instruction_handler
 db 'vcvttsd2usi',78h
 dw avx_cvttsd2usi_instruction-instruction_handler
 db 'vcvttss2usi',78h
 dw avx_cvttss2usi_instruction-instruction_handler
 db 'vfixupimmpd',54h
 dw avx512_pd_instruction_sae_imm8-instruction_handler
 db 'vfixupimmps',54h
 dw avx512_ps_instruction_sae_imm8-instruction_handler
 db 'vfixupimmsd',55h
 dw avx512_sd_instruction_sae_imm8-instruction_handler
 db 'vfixupimmss',55h
 dw avx512_ss_instruction_sae_imm8-instruction_handler
 db 'vfmadd132pd',98h
 dw fma_instruction_pd-instruction_handler
 db 'vfmadd132ps',98h
 dw fma_instruction_ps-instruction_handler
 db 'vfmadd132sd',99h
 dw fma_instruction_sd-instruction_handler
 db 'vfmadd132ss',99h
 dw fma_instruction_ss-instruction_handler
 db 'vfmadd213pd',0A8h
 dw fma_instruction_pd-instruction_handler
 db 'vfmadd213ps',0A8h
 dw fma_instruction_ps-instruction_handler
 db 'vfmadd213sd',0A9h
 dw fma_instruction_sd-instruction_handler
 db 'vfmadd213ss',0A9h
 dw fma_instruction_ss-instruction_handler
 db 'vfmadd231pd',0B8h
 dw fma_instruction_pd-instruction_handler
 db 'vfmadd231ps',0B8h
 dw fma_instruction_ps-instruction_handler
 db 'vfmadd231sd',0B9h
 dw fma_instruction_sd-instruction_handler
 db 'vfmadd231ss',0B9h
 dw fma_instruction_ss-instruction_handler
 db 'vfmaddsubpd',5Dh
 dw fma4_instruction_p-instruction_handler
 db 'vfmaddsubps',5Ch
 dw fma4_instruction_p-instruction_handler
 db 'vfmsub132pd',9Ah
 dw fma_instruction_pd-instruction_handler
 db 'vfmsub132ps',9Ah
 dw fma_instruction_ps-instruction_handler
 db 'vfmsub132sd',9Bh
 dw fma_instruction_sd-instruction_handler
 db 'vfmsub132ss',9Bh
 dw fma_instruction_ss-instruction_handler
 db 'vfmsub213pd',0AAh
 dw fma_instruction_pd-instruction_handler
 db 'vfmsub213ps',0AAh
 dw fma_instruction_ps-instruction_handler
 db 'vfmsub213sd',0ABh
 dw fma_instruction_sd-instruction_handler
 db 'vfmsub213ss',0ABh
 dw fma_instruction_ss-instruction_handler
 db 'vfmsub231pd',0BAh
 dw fma_instruction_pd-instruction_handler
 db 'vfmsub231ps',0BAh
 dw fma_instruction_ps-instruction_handler
 db 'vfmsub231sd',0BBh
 dw fma_instruction_sd-instruction_handler
 db 'vfmsub231ss',0BBh
 dw fma_instruction_ss-instruction_handler
 db 'vfmsubaddpd',5Fh
 dw fma4_instruction_p-instruction_handler
 db 'vfmsubaddps',5Eh
 dw fma4_instruction_p-instruction_handler
 db 'vinsertf128',18h
 dw avx_insertf128_instruction-instruction_handler
 db 'vinserti128',38h
 dw avx_insertf128_instruction-instruction_handler
 db 'vmaskmovdqu',0
 dw avx_maskmovdqu_instruction-instruction_handler
 db 'vpcomfalseb',6
 dw xop_pcom_b_instruction-instruction_handler
 db 'vpcomfalsed',6
 dw xop_pcom_d_instruction-instruction_handler
 db 'vpcomfalseq',6
 dw xop_pcom_q_instruction-instruction_handler
 db 'vpcomfalsew',6
 dw xop_pcom_w_instruction-instruction_handler
 db 'vpcompressd',8Bh
 dw avx_compress_d_instruction-instruction_handler
 db 'vpcompressq',8Bh
 dw avx_compress_q_instruction-instruction_handler
 db 'vpcomtrueub',7
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomtrueud',7
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomtrueuq',7
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomtrueuw',7
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpconflictd',0C4h
 dw avx_single_source_d_instruction_38_evex-instruction_handler
 db 'vpconflictq',0C4h
 dw avx_single_source_q_instruction_38_evex-instruction_handler
 db 'vphminposuw',41h
 dw avx_single_source_instruction_38_noevex-instruction_handler
 db 'vpmadd52huq',0B5h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpmadd52luq',0B4h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vpscatterdd',0A0h
 dw scatter_ps_instruction-instruction_handler
 db 'vpscatterdq',0A0h
 dw scatter_pd_instruction-instruction_handler
 db 'vpscatterqd',0A1h
 dw scatter_ps_instruction-instruction_handler
 db 'vpscatterqq',0A1h
 dw scatter_pd_instruction-instruction_handler
 db 'vpunpckhqdq',6Dh
 dw avx_q_instruction-instruction_handler
 db 'vpunpcklqdq',6Ch
 dw avx_q_instruction-instruction_handler
 db 'vrndscalepd',9
 dw avx512_single_source_pd_instruction_sae_imm8-instruction_handler
 db 'vrndscaleps',8
 dw avx512_single_source_ps_instruction_sae_imm8-instruction_handler
 db 'vrndscalesd',0Bh
 dw avx512_sd_instruction_sae_imm8-instruction_handler
 db 'vrndscaless',0Ah
 dw avx512_ss_instruction_sae_imm8-instruction_handler
 db 'vscatterdpd',0A2h
 dw scatter_pd_instruction-instruction_handler
 db 'vscatterdps',0A2h
 dw scatter_ps_instruction-instruction_handler
 db 'vscatterqpd',0A3h
 dw scatter_pd_instruction-instruction_handler
 db 'vscatterqps',0A3h
 dw scatter_ps_instruction-instruction_handler
instructions_12:
 db 'pclmulhqhqdq',10001b
 dw pclmulqdq_instruction-instruction_handler
 db 'pclmulhqlqdq',1
 dw pclmulqdq_instruction-instruction_handler
 db 'pclmullqhqdq',10000b
 dw pclmulqdq_instruction-instruction_handler
 db 'pclmullqlqdq',0
 dw pclmulqdq_instruction-instruction_handler
 db 'vbroadcastsd',19h
 dw avx_broadcastsd_instruction-instruction_handler
 db 'vbroadcastss',18h
 dw avx_broadcastss_instruction-instruction_handler
 db 'vcmpneq_oqpd',0Ch
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpneq_oqps',0Ch
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpneq_oqsd',0Ch
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpneq_oqss',0Ch
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpneq_ospd',1Ch
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpneq_osps',1Ch
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpneq_ossd',1Ch
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpneq_osss',1Ch
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpneq_uspd',14h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpneq_usps',14h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpneq_ussd',14h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpneq_usss',14h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpnge_uqpd',19h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpnge_uqps',19h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpnge_uqsd',19h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpnge_uqss',19h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpngt_uqpd',1Ah
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpngt_uqps',1Ah
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpngt_uqsd',1Ah
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpngt_uqss',1Ah
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpnle_uqpd',16h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpnle_uqps',16h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpnle_uqsd',16h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpnle_uqss',16h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpnlt_uqpd',15h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpnlt_uqps',15h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpnlt_uqsd',15h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpnlt_uqss',15h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vextractf128',19h
 dw avx_extractf128_instruction-instruction_handler
 db 'vextracti128',39h
 dw avx_extractf128_instruction-instruction_handler
 db 'vfnmadd132pd',9Ch
 dw fma_instruction_pd-instruction_handler
 db 'vfnmadd132ps',9Ch
 dw fma_instruction_ps-instruction_handler
 db 'vfnmadd132sd',9Dh
 dw fma_instruction_sd-instruction_handler
 db 'vfnmadd132ss',9Dh
 dw fma_instruction_ss-instruction_handler
 db 'vfnmadd213pd',0ACh
 dw fma_instruction_pd-instruction_handler
 db 'vfnmadd213ps',0ACh
 dw fma_instruction_ps-instruction_handler
 db 'vfnmadd213sd',0ADh
 dw fma_instruction_sd-instruction_handler
 db 'vfnmadd213ss',0ADh
 dw fma_instruction_ss-instruction_handler
 db 'vfnmadd231pd',0BCh
 dw fma_instruction_pd-instruction_handler
 db 'vfnmadd231ps',0BCh
 dw fma_instruction_ps-instruction_handler
 db 'vfnmadd231sd',0BDh
 dw fma_instruction_sd-instruction_handler
 db 'vfnmadd231ss',0BDh
 dw fma_instruction_ss-instruction_handler
 db 'vfnmsub132pd',9Eh
 dw fma_instruction_pd-instruction_handler
 db 'vfnmsub132ps',9Eh
 dw fma_instruction_ps-instruction_handler
 db 'vfnmsub132sd',9Fh
 dw fma_instruction_sd-instruction_handler
 db 'vfnmsub132ss',9Fh
 dw fma_instruction_ss-instruction_handler
 db 'vfnmsub213pd',0AEh
 dw fma_instruction_pd-instruction_handler
 db 'vfnmsub213ps',0AEh
 dw fma_instruction_ps-instruction_handler
 db 'vfnmsub213sd',0AFh
 dw fma_instruction_sd-instruction_handler
 db 'vfnmsub213ss',0AFh
 dw fma_instruction_ss-instruction_handler
 db 'vfnmsub231pd',0BEh
 dw fma_instruction_pd-instruction_handler
 db 'vfnmsub231ps',0BEh
 dw fma_instruction_ps-instruction_handler
 db 'vfnmsub231sd',0BFh
 dw fma_instruction_sd-instruction_handler
 db 'vfnmsub231ss',0BFh
 dw fma_instruction_ss-instruction_handler
 db 'vinsertf32x4',18h
 dw avx512_insert_32x4_instruction-instruction_handler
 db 'vinsertf32x8',1Ah
 dw avx512_insert_32x8_instruction-instruction_handler
 db 'vinsertf64x2',18h
 dw avx512_insert_64x2_instruction-instruction_handler
 db 'vinsertf64x4',1Ah
 dw avx512_insert_64x4_instruction-instruction_handler
 db 'vinserti32x4',38h
 dw avx512_insert_32x4_instruction-instruction_handler
 db 'vinserti32x8',3Ah
 dw avx512_insert_32x8_instruction-instruction_handler
 db 'vinserti64x2',38h
 dw avx512_insert_64x2_instruction-instruction_handler
 db 'vinserti64x4',3Ah
 dw avx512_insert_64x4_instruction-instruction_handler
 db 'vpbroadcastb',78h
 dw avx_pbroadcastb_instruction-instruction_handler
 db 'vpbroadcastd',58h
 dw avx_pbroadcastd_instruction-instruction_handler
 db 'vpbroadcastq',59h
 dw avx_pbroadcastq_instruction-instruction_handler
 db 'vpbroadcastw',79h
 dw avx_pbroadcastw_instruction-instruction_handler
 db 'vpclmulhqhdq',10001b
 dw avx_pclmulqdq_instruction-instruction_handler
 db 'vpclmullqhdq',10000b
 dw avx_pclmulqdq_instruction-instruction_handler
 db 'vpcomfalseub',6
 dw xop_pcom_ub_instruction-instruction_handler
 db 'vpcomfalseud',6
 dw xop_pcom_ud_instruction-instruction_handler
 db 'vpcomfalseuq',6
 dw xop_pcom_uq_instruction-instruction_handler
 db 'vpcomfalseuw',6
 dw xop_pcom_uw_instruction-instruction_handler
 db 'vpermilmo2pd',10b
 dw vpermil_2pd_instruction-instruction_handler
 db 'vpermilmo2ps',10b
 dw vpermil_2ps_instruction-instruction_handler
 db 'vpermilmz2pd',11b
 dw vpermil_2pd_instruction-instruction_handler
 db 'vpermilmz2ps',11b
 dw vpermil_2ps_instruction-instruction_handler
 db 'vpermiltd2pd',0
 dw vpermil_2pd_instruction-instruction_handler
 db 'vpermiltd2ps',0
 dw vpermil_2ps_instruction-instruction_handler
instructions_13:
 db 'vcmptrue_uspd',1Fh
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmptrue_usps',1Fh
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmptrue_ussd',1Fh
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmptrue_usss',1Fh
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vcmpunord_spd',13h
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpunord_sps',13h
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpunord_ssd',13h
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpunord_sss',13h
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vextractf32x4',19h
 dw avx512_extract_32x4_instruction-instruction_handler
 db 'vextractf32x8',1Bh
 dw avx512_extract_32x8_instruction-instruction_handler
 db 'vextractf64x2',19h
 dw avx512_extract_64x2_instruction-instruction_handler
 db 'vextractf64x4',1Bh
 dw avx512_extract_64x4_instruction-instruction_handler
 db 'vextracti32x4',39h
 dw avx512_extract_32x4_instruction-instruction_handler
 db 'vextracti32x8',comment_marker
 dw avx512_extract_32x8_instruction-instruction_handler
 db 'vextracti64x2',39h
 dw avx512_extract_64x2_instruction-instruction_handler
 db 'vextracti64x4',comment_marker
 dw avx512_extract_64x4_instruction-instruction_handler
 db 'vgatherpf0dpd',1
 dw gatherpf_dpd_instruction-instruction_handler
 db 'vgatherpf0dps',1
 dw gatherpf_dps_instruction-instruction_handler
 db 'vgatherpf0qpd',1
 dw gatherpf_qpd_instruction-instruction_handler
 db 'vgatherpf0qps',1
 dw gatherpf_qps_instruction-instruction_handler
 db 'vgatherpf1dpd',2
 dw gatherpf_dpd_instruction-instruction_handler
 db 'vgatherpf1dps',2
 dw gatherpf_dps_instruction-instruction_handler
 db 'vgatherpf1qpd',2
 dw gatherpf_qpd_instruction-instruction_handler
 db 'vgatherpf1qps',2
 dw gatherpf_qps_instruction-instruction_handler
 db 'vpclmulhqlqdq',1
 dw avx_pclmulqdq_instruction-instruction_handler
 db 'vpclmullqlqdq',0
 dw avx_pclmulqdq_instruction-instruction_handler
instructions_14:
 db 'vbroadcastf128',1Ah
 dw avx_broadcast_128_instruction_noevex-instruction_handler
 db 'vbroadcasti128',5Ah
 dw avx_broadcast_128_instruction_noevex-instruction_handler
 db 'vcmpfalse_ospd',1Bh
 dw avx_cmp_pd_instruction-instruction_handler
 db 'vcmpfalse_osps',1Bh
 dw avx_cmp_ps_instruction-instruction_handler
 db 'vcmpfalse_ossd',1Bh
 dw avx_cmp_sd_instruction-instruction_handler
 db 'vcmpfalse_osss',1Bh
 dw avx_cmp_ss_instruction-instruction_handler
 db 'vfmaddsub132pd',96h
 dw fma_instruction_pd-instruction_handler
 db 'vfmaddsub132ps',96h
 dw fma_instruction_ps-instruction_handler
 db 'vfmaddsub213pd',0A6h
 dw fma_instruction_pd-instruction_handler
 db 'vfmaddsub213ps',0A6h
 dw fma_instruction_ps-instruction_handler
 db 'vfmaddsub231pd',0B6h
 dw fma_instruction_pd-instruction_handler
 db 'vfmaddsub231ps',0B6h
 dw fma_instruction_ps-instruction_handler
 db 'vfmsubadd132pd',97h
 dw fma_instruction_pd-instruction_handler
 db 'vfmsubadd132ps',97h
 dw fma_instruction_ps-instruction_handler
 db 'vfmsubadd213pd',0A7h
 dw fma_instruction_pd-instruction_handler
 db 'vfmsubadd213ps',0A7h
 dw fma_instruction_ps-instruction_handler
 db 'vfmsubadd231pd',0B7h
 dw fma_instruction_pd-instruction_handler
 db 'vfmsubadd231ps',0B7h
 dw fma_instruction_ps-instruction_handler
 db 'vpmultishiftqb',83h
 dw avx_q_instruction_38_evex-instruction_handler
 db 'vscatterpf0dpd',5
 dw gatherpf_dpd_instruction-instruction_handler
 db 'vscatterpf0dps',5
 dw gatherpf_dps_instruction-instruction_handler
 db 'vscatterpf0qpd',5
 dw gatherpf_qpd_instruction-instruction_handler
 db 'vscatterpf0qps',5
 dw gatherpf_qps_instruction-instruction_handler
 db 'vscatterpf1dpd',6
 dw gatherpf_dpd_instruction-instruction_handler
 db 'vscatterpf1dps',6
 dw gatherpf_dps_instruction-instruction_handler
 db 'vscatterpf1qpd',6
 dw gatherpf_qpd_instruction-instruction_handler
 db 'vscatterpf1qps',6
 dw gatherpf_qps_instruction-instruction_handler
instructions_15:
 db 'aeskeygenassist',0DFh
 dw sse4_instruction_66_3a_imm8-instruction_handler
 db 'vbroadcastf32x2',19h
 dw avx512_broadcast_32x2_instruction-instruction_handler
 db 'vbroadcastf32x4',1Ah
 dw avx512_broadcast_32x4_instruction-instruction_handler
 db 'vbroadcastf32x8',1Bh
 dw avx512_broadcast_32x8_instruction-instruction_handler
 db 'vbroadcastf64x2',1Ah
 dw avx512_broadcast_64x2_instruction-instruction_handler
 db 'vbroadcastf64x4',1Bh
 dw avx512_broadcast_64x4_instruction-instruction_handler
 db 'vbroadcasti32x2',59h
 dw avx512_broadcast_32x2_instruction-instruction_handler
 db 'vbroadcasti32x4',5Ah
 dw avx512_broadcast_32x4_instruction-instruction_handler
 db 'vbroadcasti32x8',5Bh
 dw avx512_broadcast_32x8_instruction-instruction_handler
 db 'vbroadcasti64x2',5Ah
 dw avx512_broadcast_64x2_instruction-instruction_handler
 db 'vbroadcasti64x4',5Bh
 dw avx512_broadcast_64x4_instruction-instruction_handler
 db 'vpbroadcastmb2q',2Ah
 dw avx512_pmov_m2_instruction_w1-instruction_handler
 db 'vpbroadcastmw2d',3Ah
 dw avx512_pmov_m2_instruction-instruction_handler
instructions_16:
 db 'vaeskeygenassist',0DFh
 dw avx_single_source_128bit_instruction_3a_imm8_noevex-instruction_handler
instructions_end:

data_directives:
 dw data_directives_2-data_directives,(data_directives_3-data_directives_2)/(2+3)
 dw data_directives_3-data_directives,(data_directives_4-data_directives_3)/(3+3)
 dw data_directives_4-data_directives,(data_directives_end-data_directives_4)/(4+3)

data_directives_2:
 db 'db',1
 dw data_bytes-instruction_handler
 db 'dd',4
 dw data_dwords-instruction_handler
 db 'df',6
 dw data_pwords-instruction_handler
 db 'dp',6
 dw data_pwords-instruction_handler
 db 'dq',8
 dw data_qwords-instruction_handler
 db 'dt',10
 dw data_twords-instruction_handler
 db 'du',2
 dw data_unicode-instruction_handler
 db 'dw',2
 dw data_words-instruction_handler
 db 'rb',1
 dw reserve_bytes-instruction_handler
 db 'rd',4
 dw reserve_dwords-instruction_handler
 db 'rf',6
 dw reserve_pwords-instruction_handler
 db 'rp',6
 dw reserve_pwords-instruction_handler
 db 'rq',8
 dw reserve_qwords-instruction_handler
 db 'rt',10
 dw reserve_twords-instruction_handler
 db 'rw',2
 dw reserve_words-instruction_handler
data_directives_3:
data_directives_4:
 db 'file',1
 dw data_file-instruction_handler
data_directives_end:
