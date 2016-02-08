add_macro_symbol:
	push	ebx ebp
	call	find_macro_symbol_leaf
	jc	extend_macro_symbol_tree
	mov	eax,[ebx]
      make_macro_symbol:
	mov	edx,[free_additional_memory]
	add	edx,16
	cmp	edx,[labels_list]
	ja	out_of_memory
	xchg	edx,[free_additional_memory]
	mov	[ebx],edx
	mov	[edx],eax
	mov	[edx+4],esi
	pop	ebp ebx
	ret
      extend_macro_symbol_tree:
	mov	edx,[free_additional_memory]
	add	edx,16
	cmp	edx,[labels_list]
	ja	out_of_memory
	xchg	edx,[free_additional_memory]
	xor	eax,eax
	mov	[edx],eax
	mov	[edx+4],eax
	mov	[edx+8],eax
	mov	[edx+12],eax
	shr	ebp,1
	adc	eax,0
	mov	[ebx],edx
	lea	ebx,[edx+eax*4]
	or	ebp,ebp
	jnz	extend_macro_symbol_tree
	add	ebx,8
	xor	eax,eax
	jmp	make_macro_symbol
