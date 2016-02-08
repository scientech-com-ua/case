do_match:
	mov	ebx,esi
	call	skip_pattern
	call	exact_match
	mov	edx,edi
	mov	al,[ebx]
	cmp	al,1Ah
	je	free_match
	cmp	al,','
	jne	instant_macro_done
	cmp	esi,[parameters_end]
	je	matched_pattern
	jmp	instant_macro_done
      free_match:
	add	edx,12
	cmp	edx,[memory_end]
	ja	out_of_memory
	mov	[edx-12],ebx
	mov	[edx-8],esi
	call	skip_match_element
	jc	try_different_matching
	mov	[edx-4],esi
	movzx	eax,byte [ebx+1]
	lea	ebx,[ebx+2+eax]
	cmp	byte [ebx],1Ah
	je	free_match
      find_exact_match:
	call	exact_match
	cmp	esi,[parameters_end]
	je	end_matching
	cmp	byte [ebx],1Ah
	je	free_match
	mov	ebx,[edx-12]
	movzx	eax,byte [ebx+1]
	lea	ebx,[ebx+2+eax]
	mov	esi,[edx-4]
	jmp	match_more_elements
      try_different_matching:
	sub	edx,12
	cmp	edx,edi
	je	instant_macro_done
	mov	ebx,[edx-12]
	movzx	eax,byte [ebx+1]
	lea	ebx,[ebx+2+eax]
	cmp	byte [ebx],1Ah
	je	try_different_matching
	mov	esi,[edx-4]
      match_more_elements:
	call	skip_match_element
	jc	try_different_matching
	mov	[edx-4],esi
	jmp	find_exact_match
      skip_match_element:
	cmp	esi,[parameters_end]
	je	cannot_match
	mov	al,[esi]
	cmp	al,1Ah
	je	skip_match_symbol
	cmp	al,22h
	je	skip_match_quoted_string
	add	esi,1
	ret
      skip_match_quoted_string:
	mov	eax,[esi+1]
	add	esi,5
	jmp	skip_match_ok
      skip_match_symbol:
	movzx	eax,byte [esi+1]
	add	esi,2
      skip_match_ok:
	add	esi,eax
	ret
      cannot_match:
	stc
	ret
      exact_match:
	cmp	esi,[parameters_end]
	je	exact_match_complete
	mov	ah,[esi]
	mov	al,[ebx]
	cmp	al,','
	je	exact_match_complete
	cmp	al,1Ah
	je	exact_match_complete
	cmp	al,'='
	je	match_verbatim
	call	match_elements
	je	exact_match
      exact_match_complete:
	ret
      match_verbatim:
	inc	ebx
	call	match_elements
	je	exact_match
	dec	ebx
	ret
      match_elements:
	mov	al,[ebx]
	cmp	al,1Ah
	je	match_symbols
	cmp	al,22h
	je	match_quoted_strings
	cmp	al,ah
	je	symbol_characters_matched
	ret
      symbol_characters_matched:
	lea	ebx,[ebx+1]
	lea	esi,[esi+1]
	ret
      match_quoted_strings:
	mov	ecx,[ebx+1]
	add	ecx,5
	jmp	compare_elements
      match_symbols:
	movzx	ecx,byte [ebx+1]
	add	ecx,2
      compare_elements:
	mov	eax,esi
	mov	ebp,edi
	mov	edi,ebx
	repe	cmps byte [esi],[edi]
	jne	elements_mismatch
	mov	ebx,edi
	mov	edi,ebp
	ret
      elements_mismatch:
	mov	esi,eax
	mov	edi,ebp
	ret
      end_matching:
	cmp	byte [ebx],','
	jne	instant_macro_done
      matched_pattern:
	xor	eax,eax
	push	[free_additional_memory]
	push	[macro_symbols]
	mov	[macro_symbols],eax
	push	[counter_limit]
	mov	[counter_limit],eax
	mov	[struc_name],eax
	push	esi edi edx
      add_matched_symbol:
	cmp	edi,[esp]
	je	matched_symbols_ok
	mov	esi,[edi]
	inc	esi
	lods	byte [esi]
	movzx	ecx,al
	xor	eax,eax
	call	add_macro_symbol
	mov	eax,[edi+4]
	mov	dword [edx+12],eax
	mov	ecx,[edi+8]
	sub	ecx,eax
	mov	dword [edx+8],ecx
	add	edi,12
	jmp	add_matched_symbol
      matched_symbols_ok:
	pop	edx edi esi
	jmp	instant_macro_parameters_ok
