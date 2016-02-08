add_preprocessor_symbol:
	push	edi esi
	xor	eax,eax
	or	cl,cl
	jz	reshape_hash
	cmp	ch,11b
	je	preprocessor_symbol_name_ok
	push	ecx
	movzx	ecx,cl
	mov	edi,preprocessor_directives
	call	get_directive
	jnc	reserved_word_used_as_symbol
	pop	ecx
      preprocessor_symbol_name_ok:
	call	calculate_hash
      reshape_hash:
	mov	ebp,eax
	and	ebp,3FFh
	shr	eax,10
	xor	ebp,eax
	shl	ecx,22
	or	ebp,ecx
	mov	ebx,hash_tree
	mov	ecx,32
      find_leave_for_symbol:
	mov	edx,[ebx]
	or	edx,edx
	jz	extend_hashes_tree
	xor	eax,eax
	rol	ebp,1
	adc	eax,0
	lea	ebx,[edx+eax*4]
	dec	ecx
	jnz	find_leave_for_symbol
	mov	edx,[ebx]
	or	edx,edx
	jz	add_symbol_entry
	shr	ebp,30
	cmp	ebp,11b
	je	reuse_symbol_entry
	cmp	dword [edx+4],0
	jne	add_symbol_entry
      find_entry_to_reuse:
	mov	edi,[edx]
	or	edi,edi
	jz	reuse_symbol_entry
	cmp	dword [edi+4],0
	jne	reuse_symbol_entry
	mov	edx,edi
	jmp	find_entry_to_reuse
      add_symbol_entry:
	mov	eax,edx
	mov	edx,[labels_list]
	sub	edx,16
	cmp	edx,[free_additional_memory]
	jb	out_of_memory
	mov	[labels_list],edx
	mov	[edx],eax
	mov	[ebx],edx
      reuse_symbol_entry:
	pop	esi edi
	mov	[edx+4],esi
	ret
      extend_hashes_tree:
	mov	edx,[labels_list]
	sub	edx,8
	cmp	edx,[free_additional_memory]
	jb	out_of_memory
	mov	[labels_list],edx
	xor	eax,eax
	mov	[edx],eax
	mov	[edx+4],eax
	shl	ebp,1
	adc	eax,0
	mov	[ebx],edx
	lea	ebx,[edx+eax*4]
	dec	ecx
	jnz	extend_hashes_tree
	mov	edx,[labels_list]
	sub	edx,16
	cmp	edx,[free_additional_memory]
	jb	out_of_memory
	mov	[labels_list],edx
	mov	dword [edx],0
	mov	[ebx],edx
	pop	esi edi
	mov	[edx+4],esi
	ret
