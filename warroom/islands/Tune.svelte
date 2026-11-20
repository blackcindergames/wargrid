<svelte:options
	customElement={{
		tag: 'wr-tune',
		shadow: 'none',
		props: {
			params: { attribute: 'data-params', type: 'Array' },
			target: { attribute: 'data-target' },
			field: { attribute: 'data-field' },
		},
	}}
/>

<script>
	import { Pane } from 'tweakpane';

	let { params, target, field } = $props();

	const options = (p) => ({
		label: p.label,
		...(p.kind === 'number' && { min: p.min, max: p.max, step: p.step }),
		...(p.kind === 'color' && { view: 'color' }),
		...(p.kind === 'choice' && { options: p.values.map((v) => ({ text: v, value: v })) }),
	});

	$effect(() => {
		// Plain object, not $state: Tweakpane writes into it and the effect must not track those writes.
		const values = Object.fromEntries(params.map((p) => [p.id, p.value]));
		const pane = new Pane({ container: $host() });
		for (const p of params) pane.addBinding(values, p.id, options(p));

		const frame = document.getElementById(target);
		const send = () => {
			const input = document.getElementById(field);
			if (input) input.value = JSON.stringify(values);
			frame?.contentWindow?.postMessage({ type: 'wr:params', params: values }, location.origin);
		};
		pane.on('change', send);
		frame?.addEventListener('load', send);
		return () => {
			frame?.removeEventListener('load', send);
			pane.dispose();
		};
	});
</script>
