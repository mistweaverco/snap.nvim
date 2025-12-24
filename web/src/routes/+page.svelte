<script lang="ts">
	import HeadComponent from '$lib/HeadComponent.svelte';

	const handleAnchorClick = (evt: Event) => {
		evt.preventDefault();
		const link = evt.currentTarget as HTMLAnchorElement;
		const anchorId = new URL(link.href).hash.replace('#', '');
		const anchor = document.getElementById(anchorId);
		window.scrollTo({
			top: anchor?.offsetTop,
			behavior: 'smooth'
		});
	};
</script>

<HeadComponent
	data={{
		title: 'Snap.nvim',
		description:
			'A minimal screenshot plugin for Neovim. It respects your current color scheme to ensure that the screenshots blend seamlessly with your Neovim setup'
	}}
/>

<div id="start" class="hero bg-base-200 min-h-screen">
	<div class="hero-content text-center">
		<div class="max-w-md">
			<img src="/logo.svg" alt="Snap.nvim" class="m-5 mx-auto w-64" />
			<h1 class="text-5xl font-bold">Snap.nvim</h1>
			<p class="py-6">A minimal screenshot plugin for Neovim.</p>
			<a href="#what" on:click={handleAnchorClick}><button class="btn btn-primary">What?</button></a>
		</div>
	</div>
</div>
<div id="what" class="hero bg-base-200 min-h-screen">
	<div class="hero-content text-center">
		<div class="max-w-md">
			<h1 class="text-5xl font-bold">What? 🤔</h1>
			<p class="py-6">
				It respects your current color scheme to ensure that the screenshots blend seamlessly with your Neovim setup.
			</p>
			<p class="py-6">
				Snap.nvim tries to <em>collect</em> information about your Neovim highlights and then sends it off to the backend
				to create a screenshot and copy the contents your OS clipboard.
			</p>
			<p class="py-6">
				Most other screenshot tools just have some fixed themes schemes that don't match your Neovim setup.
			</p>
			<p>
				<a href="#comparison" on:click={handleAnchorClick}><button class="btn btn-primary mt-5">Comparison</button></a>
			</p>
		</div>
	</div>
</div>
<div id="comparison" class="bg-base-200 min-h-screen flex flex-col justify-center">
	<div class="text-center mb-10">
		<h1 class="text-5xl font-bold">Comparison 📸</h1>
		<p class="pt-6">On the left side, there is "a real screenshot" with an external tool.</p>
		<p class="pt-6">And on the right side, there is "a snap" screenshot via Snap.nvim.</p>
	</div>
	<div class="text-center">
		<figure class="diff mx-auto w-full max-w-4xl aspect-[4/3]">
			<div class="diff-item-1" role="img">
				<div class="bg-base-300 grid place-content-center object-cover">
					<img src="/screenshots/screenshot_jsdoc_todo_comment.png" alt="Screenshot of jsdoc with todo comment" />
				</div>
			</div>
			<div class="diff-item-2" role="img">
				<div class="bg-base-300 grid place-content-center object-cover">
					<img src="/screenshots/snap_jsdoc_todo_comment.png" alt="Snap of jsodc with todo comment" />
				</div>
			</div>
			<div class="diff-resizer"></div>
		</figure>
		<div class="text-center">
			<p>
				<a href="#get-involved" on:click={handleAnchorClick}
					><button class="btn btn-secondary mt-5">Get involved</button></a
				>
			</p>
		</div>
	</div>
</div>
<div id="get-involved" class="hero bg-base-200 min-h-screen">
	<div class="hero-content text-center">
		<div class="max-w-md">
			<h1 class="text-5xl font-bold">Get involved ❤️</h1>
			<p class="py-6">Snap.nvim is open-source and we welcome contributions.</p>
			<p>
				View the <a class="text-secondary" href="https://github.com/mistweaverco/snap.nvim">code.</a>
			</p>
		</div>
	</div>
</div>
