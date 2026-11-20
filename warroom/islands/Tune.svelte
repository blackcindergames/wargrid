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

<script lang="ts">
	import { Pane } from 'tweakpane';
	import type { BindingParams } from 'tweakpane';

	type Base = { id: string; label: string };
	type Param =
		| (Base & { kind: 'number'; value: number; min: number; max: number; step: number })
		| (Base & { kind: 'color'; value: string })
		| (Base & { kind: 'choice'; value: string; values: string[] });

	let { params, target, field }: { params: Param[]; target: string; field: string } = $props();

	const options = (p: Param): BindingParams => {
		switch (p.kind) {
			case 'number':
				return { label: p.label, min: p.min, max: p.max, step: p.step };
			case 'color':
				return { label: p.label, view: 'color' };
			case 'choice':
				return { label: p.label, options: p.values.map((v) => ({ text: v, value: v })) };
		}
	};

	$effect(() => {
		// Plain object, not $state: Tweakpane writes into it and the effect must not track those writes.
		const values: Record<string, number | string> = Object.fromEntries(params.map((p) => [p.id, p.value]));
		const pane = new Pane({ container: $host() });
		for (const p of params) pane.addBinding(values, p.id, options(p));

		const frame = document.getElementById(target) as HTMLIFrameElement | null;
		const send = () => {
			const input = document.getElementById(field) as HTMLInputElement | null;
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
