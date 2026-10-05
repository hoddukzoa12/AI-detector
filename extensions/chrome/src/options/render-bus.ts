type AsyncAction = () => Promise<void>;

let renderImpl: AsyncAction = () => Promise.resolve();
let renderTemplatesImpl: AsyncAction = () => Promise.resolve();

export function setRenderImpl(render: AsyncAction, renderTemplates: AsyncAction): void {
  renderImpl = render;
  renderTemplatesImpl = renderTemplates;
}

export function requestRender(): Promise<void> {
  return renderImpl();
}

export function requestRenderTemplates(): Promise<void> {
  return renderTemplatesImpl();
}
