convert_line:
	push	ecx
	test	[macro_status],0Fh
	jz	convert_line_data
	mov	ax,3Bh
	stos	word [edi]
      convert_line_data:
	cmp	edi,[memory_end]
	jae	out_of_memory
	lods	byte [esi]
	cmp	al,20h
	je	convert_line_data
	cmp	al,9
	je	convert_line_data
	mov	ah,al
	mov	ebx,characters
	xlat	byte [ebx]
	or	al,al
	jz	convert_separator
	cmp	ah,27h
	je	convert_string
	cmp	ah,22h
	je	convert_string
	mov	byte [edi],1Ah
	scas	word [edi]
	xchg	al,ah
	stos	byte [edi]
	mov	ebx,characters
	xor	ecx,ecx
      convert_symbol:
	lods	byte [esi]
	stos	byte [edi]
	xlat	byte [ebx]
	or	al,al
	loopnzd convert_symbol
	neg	ecx
	cmp	ecx,255
	ja	name_too_long
	mov	ebx,edi
	sub	ebx,ecx
	mov	byte [ebx-2],cl
      found_separator:
	dec	edi
	mov	ah,[esi-1]
      convert_separator:
	xchg	al,ah
	cmp	al,20h
	jb	control_character
	je	convert_line_data
      symbol_character:
	cmp	al,3Bh
	je	ignore_comment
	cmp	al,5Ch
	je	backslash_character
	stos	byte [edi]
	jmp	convert_line_data
      control_character:
	cmp	al,1Ah
	je	line_end
	cmp	al,0Dh
	je	cr_character
	cmp	al,0Ah
	je	lf_character
	cmp	al,9
	je	convert_line_data
	or	al,al
	jnz	symbol_character
	jmp	line_end
      lf_character:
	lods	byte [esi]
	cmp	al,0Dh
	je	line_end
	dec	esi
	jmp	line_end
      cr_character:
	lods	byte [esi]
	cmp	al,0Ah
	je	line_end
	dec	esi
	jmp	line_end
      convert_string:
	mov	al,22h
	stos	byte [edi]
	scas	dword [edi]
	mov	ebx,edi
      copy_string:
	lods	byte [esi]
	stos	byte [edi]
	cmp	al,0Ah
	je	no_end_quote
	cmp	al,0Dh
	je	no_end_quote
	or	al,al
	jz	no_end_quote
	cmp	al,1Ah
	je	no_end_quote
	cmp	al,ah
	jne	copy_string
	lods	byte [esi]
	cmp	al,ah
	je	copy_string
	dec	esi
	dec	edi
	mov	eax,edi
	sub	eax,ebx
	mov	[ebx-4],eax
	jmp	convert_line_data
      backslash_character:
	mov	byte [edi],0
	lods	byte [esi]
	cmp	al,20h
	je	concatenate_lines
	cmp	al,9
	je	concatenate_lines
	cmp	al,1Ah
	je	unexpected_end_of_file
	or	al,al
	jz	unexpected_end_of_file
	cmp	al,0Ah
	je	concatenate_lf
	cmp	al,0Dh
	je	concatenate_cr
	cmp	al,3Bh
	je	find_concatenated_line
	mov	al,1Ah
	stos	byte [edi]
	mov	ecx,edi
	mov	ax,5C01h
	stos	word [edi]
	dec	esi
      group_backslashes:
	lods	byte [esi]
	cmp	al,5Ch
	jne	backslashed_symbol
	stos	byte [edi]
	inc	byte [ecx]
	jz	name_too_long
	jmp	group_backslashes
      no_end_quote:
	mov	byte [ebx-5],0
	jmp	missing_end_quote
      backslashed_symbol:
	cmp	al,1Ah
	je	unexpected_end_of_file
	or	al,al
	jz	unexpected_end_of_file
	cmp	al,0Ah
	je	extra_characters_on_line
	cmp	al,0Dh
	je	extra_characters_on_line
	cmp	al,20h
	je	extra_characters_on_line
	cmp	al,9
	je	extra_characters_on_line
	cmp	al,22h
	je	extra_characters_on_line
	cmp	al,27h
	je	extra_characters_on_line
	cmp	al,3Bh
	je	extra_characters_on_line
	mov	ah,al
	mov	ebx,characters
	xlat	byte [ebx]
	or	al,al
	jz	backslashed_symbol_character
	mov	al,ah
      convert_backslashed_symbol:
	stos	byte [edi]
	xlat	byte [ebx]
	or	al,al
	jz	found_separator
	inc	byte [ecx]
	jz	name_too_long
	lods	byte [esi]
	jmp	convert_backslashed_symbol
      backslashed_symbol_character:
	mov	al,ah
	stos	byte [edi]
	inc	byte [ecx]
	jmp	convert_line_data
      concatenate_lines:
	lods	byte [esi]
	cmp	al,20h
	je	concatenate_lines
	cmp	al,9
	je	concatenate_lines
	cmp	al,1Ah
	je	unexpected_end_of_file
	or	al,al
	jz	unexpected_end_of_file
	cmp	al,0Ah
	je	concatenate_lf
	cmp	al,0Dh
	je	concatenate_cr
	cmp	al,3Bh
	jne	extra_characters_on_line
      find_concatenated_line:
	lods	byte [esi]
	cmp	al,0Ah
	je	concatenate_lf
	cmp	al,0Dh
	je	concatenate_cr
	or	al,al
	jz	concatenate_ok
	cmp	al,1Ah
	jne	find_concatenated_line
	jmp	unexpected_end_of_file
      concatenate_lf:
	lods	byte [esi]
	cmp	al,0Dh
	je	concatenate_ok
	dec	esi
	jmp	concatenate_ok
      concatenate_cr:
	lods	byte [esi]
	cmp	al,0Ah
	je	concatenate_ok
	dec	esi
      concatenate_ok:
	inc	dword [esp]
	jmp	convert_line_data
      ignore_comment:
	lods	byte [esi]
	cmp	al,0Ah
	je	lf_character
	cmp	al,0Dh
	je	cr_character
	or	al,al
	jz	line_end
	cmp	al,1Ah
	jne	ignore_comment
      line_end:
	xor	al,al
	stos	byte [edi]
	pop	ecx
	ret
