close_macro_block:
	cmp	esi,[macro_block]
	je	block_closed
	cmp	[counter],0
	je	block_closed
	jl	reverse_counter
	mov	eax,[counter]
	cmp	eax,[counter_limit]
	je	block_closed
	inc	[counter]
	jmp	continue_block
      reverse_counter:
	mov	eax,[counter]
	dec	eax
	cmp	eax,80000000h
	je	block_closed
	mov	[counter],eax
      continue_block:
	mov	esi,[macro_block]
	mov	eax,[macro_block_line]
	mov	[macro_line],eax
	mov	ecx,[macro_block_line_number]
	stc
	ret
      block_closed:
	clc
	ret
