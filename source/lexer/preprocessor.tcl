comment_marker equ '#'
old_dies equ '!'

preprocessor:
	mov	edi,characters
	xor	al,al
      make_characters_table:
	stosb
	inc	al
	jnz	make_characters_table
	mov	esi,characters+'a'
	mov	edi,characters+'A'
	mov	ecx,26
	rep	movsb
	mov	edi,characters
	mov	esi,symbol_characters+1
	movzx	ecx,byte [esi-1]
	xor	eax,eax
      mark_symbol_characters:
	lodsb
	mov	byte [edi+eax],0
	loop	mark_symbol_characters
	mov	edi,locals_counter
	mov	ax,1 + '0' shl 8
	stos	word [edi]
	mov	edi,[memory_start]
	mov	[include_paths],edi
	mov	esi,include_variable
	call	get_environment_variable
	xor	al,al
	stos	byte [edi]
	mov	[memory_start],edi
	mov	eax,[additional_memory]
	mov	[free_additional_memory],eax
	mov	eax,[additional_memory_end]
	mov	[labels_list],eax
	xor	eax,eax
	mov	[source_start],eax
	mov	[tagged_blocks],eax
	mov	[hash_tree],eax
	mov	[error],eax
	mov	[macro_status],al
	mov	[current_line],eax
	mov	esi,[initial_definitions]
	test	esi,esi
	jz	predefinitions_ok
      process_predefinitions:
	movzx	ecx,byte [esi]
	test	ecx,ecx
	jz	predefinitions_ok
	inc	esi
	lea	eax,[esi+ecx]
	push	eax
	mov	ch,10b
	call	add_preprocessor_symbol
	pop	esi
	mov	edi,[memory_start]
	mov	[edx+8],edi
      convert_predefinition:
	cmp	edi,[memory_end]
	jae	out_of_memory
	lods	byte [esi]
	or	al,al
	jz	predefinition_converted
	cmp	al,20h
	je	convert_predefinition
	mov	ah,al
	mov	ebx,characters
	xlat	byte [ebx]
	or	al,al
	jz	predefinition_separator
	cmp	ah,27h
	je	predefinition_string
	cmp	ah,22h
	je	predefinition_string
	mov	byte [edi],1Ah
	scas	word [edi]
	xchg	al,ah
	stos	byte [edi]
	mov	ebx,characters
	xor	ecx,ecx
      predefinition_symbol:
	lods	byte [esi]
	stos	byte [edi]
	xlat	byte [ebx]
	or	al,al
	loopnzd predefinition_symbol
	neg	ecx
	cmp	ecx,255
	ja	invalid_definition
	mov	ebx,edi
	sub	ebx,ecx
	mov	byte [ebx-2],cl
      found_predefinition_separator:
	dec	edi
	mov	ah,[esi-1]
      predefinition_separator:
	xchg	al,ah
	or	al,al
	jz	predefinition_converted
	cmp	al,20h
	je	convert_line_data
	cmp	al,comment_marker
	je	invalid_definition
	cmp	al,5Ch
	je	predefinition_backslash
	stos	byte [edi]
	jmp	convert_predefinition
      predefinition_string:
	mov	al,22h
	stos	byte [edi]
	scas	dword [edi]
	mov	ebx,edi
      copy_predefinition_string:
	lods	byte [esi]
	stos	byte [edi]
	or	al,al
	jz	invalid_definition
	cmp	al,ah
	jne	copy_predefinition_string
	lods	byte [esi]
	cmp	al,ah
	je	copy_predefinition_string
	dec	esi
	dec	edi
	mov	eax,edi
	sub	eax,ebx
	mov	[ebx-4],eax
	jmp	convert_predefinition
      predefinition_backslash:
	mov	byte [edi],0
	lods	byte [esi]
	or	al,al
	jz	invalid_definition
	cmp	al,20h
	je	invalid_definition
	cmp	al,comment_marker
	je	invalid_definition
	mov	al,1Ah
	stos	byte [edi]
	mov	ecx,edi
	mov	ax,5C01h
	stos	word [edi]
	dec	esi
      group_predefinition_backslashes:
	lods	byte [esi]
	cmp	al,5Ch
	jne	predefinition_backslashed_symbol
	stos	byte [edi]
	inc	byte [ecx]
	jmp	group_predefinition_backslashes
      predefinition_backslashed_symbol:
	cmp	al,20h
	je	invalid_definition
	cmp	al,22h
	je	invalid_definition
	cmp	al,27h
	je	invalid_definition
	cmp	al,comment_marker
	je	invalid_definition
	mov	ah,al
	mov	ebx,characters
	xlat	byte [ebx]
	or	al,al
	jz	predefinition_backslashed_symbol_character
	mov	al,ah
      convert_predefinition_backslashed_symbol:
	stos	byte [edi]
	xlat	byte [ebx]
	or	al,al
	jz	found_predefinition_separator
	inc	byte [ecx]
	jz	invalid_definition
	lods	byte [esi]
	jmp	convert_predefinition_backslashed_symbol
      predefinition_backslashed_symbol_character:
	mov	al,ah
	stos	byte [edi]
	inc	byte [ecx]
	jmp	convert_predefinition
      predefinition_converted:
	mov	[memory_start],edi
	sub	edi,[edx+8]
	mov	[edx+12],edi
	jmp	process_predefinitions
      predefinitions_ok:
	mov	esi,[input_file]
	mov	edx,esi
	call	open
	jc	main_file_not_found
	mov	edi,[memory_start]
	call	preprocess_file
	cmp	[macro_status],0
	je	process_postponed
	mov	eax,[error_line]
	mov	[current_line],eax
	jmp	incomplete_macro
      process_postponed:
	mov	edx,hash_tree
	mov	ecx,32
      find_postponed_list:
	mov	edx,[edx]
	or	edx,edx
	loopnz	find_postponed_list
	jz	preprocessing_finished
      process_postponed_list:
	mov	eax,[edx]
	or	eax,eax
	jz	preprocessing_finished
	push	edx
	mov	ebx,edx
      find_earliest_postponed:
	mov	eax,[edx]
	or	eax,eax
	jz	earliest_postponed_found
	mov	ebx,edx
	mov	edx,eax
	jmp	find_earliest_postponed
      earliest_postponed_found:
	mov	[ebx],eax
	call	use_postponed_macro
	pop	edx
	cmp	[macro_status],0
	je	process_postponed_list
	mov	eax,[error_line]
	mov	[current_line],eax
	jmp	incomplete_macro
      preprocessing_finished:
	mov	[source_start],edi
	ret
      use_postponed_macro:
	lea	esi,[edi-1]
	push	ecx esi
	mov	[struc_name],0
	jmp	use_macro
