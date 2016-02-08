get_preprocessor_symbol:
	push	ebp edi esi
	mov	ebp,ecx
	shl	ebp,22
	movzx	ecx,cl
	mov	ebx,hash_tree
	mov	edi,10
      follow_hashes_roots:
	mov	edx,[ebx]
	or	edx,edx
	jz	preprocessor_symbol_not_found
	xor	eax,eax
	shl	ebp,1
	adc	eax,0
	lea	ebx,[edx+eax*4]
	dec	edi
	jnz	follow_hashes_roots
	mov	edi,ebx
	call	calculate_hash
	mov	ebp,eax
	and	ebp,3FFh
	shl	ebp,10
	xor	ebp,eax
	mov	ebx,edi
	mov	edi,22
      follow_hashes_tree:
	mov	edx,[ebx]
	or	edx,edx
	jz	preprocessor_symbol_not_found
	xor	eax,eax
	shl	ebp,1
	adc	eax,0
	lea	ebx,[edx+eax*4]
	dec	edi
	jnz	follow_hashes_tree
	mov	al,cl
	mov	edx,[ebx]
	or	edx,edx
	jz	preprocessor_symbol_not_found
      compare_with_preprocessor_symbol:
	mov	edi,[edx+4]
	cmp	edi,1
	jbe	next_equal_hash
	repe	cmps byte [esi],[edi]
	je	preprocessor_symbol_found
	mov	cl,al
	mov	esi,[esp]
      next_equal_hash:
	mov	edx,[edx]
	or	edx,edx
	jnz	compare_with_preprocessor_symbol
      preprocessor_symbol_not_found:
	pop	esi edi ebp
	stc
	ret
      preprocessor_symbol_found:
	pop	ebx edi ebp
	clc
	ret
      calculate_hash:
	xor	ebx,ebx
	mov	eax,2166136261
	mov	ebp,16777619
      fnv1a_hash:
	xor	al,[esi+ebx]
	mul	ebp
	inc	bl
	cmp	bl,cl
	jb	fnv1a_hash
	ret
